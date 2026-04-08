#!/usr/bin/env node
'use strict';

const fs = require('fs');
const https = require('https');
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
require('dotenv').config();

const PORT = Number.parseInt(process.env.PORT || '8443', 10);
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/modernbank?tls=true';
const JWT_SECRET = process.env.JWT_SECRET || 'replace-me-with-strong-secret';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '30m';
const INTERNAL_API_TOKEN = process.env.INTERNAL_API_TOKEN || 'replace-me-internal-token';
const TOKENIZATION_KEY = process.env.TOKENIZATION_KEY || 'replace-me-tokenization-key';
const TLS_CERT_PATH = process.env.TLS_CERT_PATH || '/opt/modernbank-backend/certs/backend.crt';
const TLS_KEY_PATH = process.env.TLS_KEY_PATH || '/opt/modernbank-backend/certs/backend.key';
const MONGO_TLS_CA_FILE = process.env.MONGO_TLS_CA_FILE || '';
const MONGO_TLS_ALLOW_INVALID_CERTS = (process.env.MONGO_TLS_ALLOW_INVALID_CERTS || 'true') === 'true';
const FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN || 'https://10.0.10.105';

const DEMO_USERNAME = process.env.DEMO_USERNAME || 'julia.ross';
const DEMO_PASSWORD = process.env.DEMO_PASSWORD || 'BankDemo!2026';
const DEMO_USER_ID = process.env.DEMO_USER_ID || '1001';

function parseNumber(value, fallback) {
    const parsed = Number.parseInt(value, 10);
    if (Number.isNaN(parsed)) {
        return fallback;
    }
    return parsed;
}

function timingSafeEquals(left, right) {
    if (typeof left !== 'string' || typeof right !== 'string') {
        return false;
    }

    const leftBuffer = Buffer.from(left, 'utf8');
    const rightBuffer = Buffer.from(right, 'utf8');

    if (leftBuffer.length !== rightBuffer.length) {
        return false;
    }

    return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function buildTokenizationKey(rawValue) {
    if (/^[a-fA-F0-9]{64}$/.test(rawValue)) {
        return Buffer.from(rawValue, 'hex');
    }

    return crypto.createHash('sha256').update(rawValue, 'utf8').digest();
}

const tokenizationKey = buildTokenizationKey(TOKENIZATION_KEY);

function tokenizeValue(input) {
    const source = String(input || '').trim();
    if (source === '') {
        return '';
    }

    const digest = crypto
        .createHmac('sha256', tokenizationKey)
        .update(source, 'utf8')
        .digest('hex');

    return `tok_${digest}`;
}

const securityEventSchema = new mongoose.Schema(
    {
        eventType: { type: String, required: true, trim: true },
        actorToken: { type: String, default: '' },
        sourceIpToken: { type: String, default: '' },
        userAgentToken: { type: String, default: '' },
        outcome: { type: String, default: 'unknown' },
        createdAt: { type: Date, default: Date.now },
    },
    {
        collection: 'security_events',
        versionKey: false,
    }
);

const secureRecordSchema = new mongoose.Schema(
    {
        userId: { type: String, required: true, index: true },
        label: { type: String, required: true, trim: true, maxlength: 120 },
        accountToken: { type: String, required: true, index: true },
        accountLast4: { type: String, required: true, minlength: 4, maxlength: 4 },
        noteToken: { type: String, default: '' },
        createdAt: { type: Date, default: Date.now },
    },
    {
        collection: 'secure_records',
        versionKey: false,
    }
);

const SecurityEvent = mongoose.model('SecurityEvent', securityEventSchema);
const SecureRecord = mongoose.model('SecureRecord', secureRecordSchema);

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);

const allowedOrigins = [
    FRONTEND_ORIGIN,
    'https://10.0.10.105',
    'https://localhost',
    'https://127.0.0.1',
];

app.use(
    helmet({
        contentSecurityPolicy: false,
        crossOriginEmbedderPolicy: false,
    })
);

app.use(
    cors({
        origin(origin, callback) {
            if (!origin || allowedOrigins.includes(origin)) {
                return callback(null, true);
            }
            return callback(new Error('Origin not allowed'));
        },
        methods: ['GET', 'POST', 'PUT', 'DELETE'],
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Internal-Token'],
        credentials: false,
    })
);

app.use(express.json({ limit: '32kb' }));

app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    next();
});

function requireInternalToken(req, res, next) {
    const incomingToken = req.get('x-internal-token') || '';

    if (!timingSafeEquals(incomingToken, INTERNAL_API_TOKEN)) {
        return res.status(401).json({ error: 'Missing or invalid service token.' });
    }

    return next();
}

app.use('/api', requireInternalToken);

function extractBearerToken(req) {
    const authHeader = req.get('authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
        return '';
    }
    return authHeader.slice(7).trim();
}

function requireJwt(req, res, next) {
    const token = extractBearerToken(req);
    if (token === '') {
        return res.status(401).json({ error: 'Missing bearer token.' });
    }

    try {
        const payload = jwt.verify(token, JWT_SECRET, {
            issuer: 'modernbank-backend',
            audience: 'modernbank-frontend',
        });

        req.auth = {
            userId: String(payload.sub || ''),
            username: String(payload.username || ''),
            role: String(payload.role || 'user'),
        };

        return next();
    } catch (error) {
        return res.status(401).json({ error: 'Invalid or expired bearer token.' });
    }
}

async function recordSecurityEvent(eventType, username, req, outcome) {
    try {
        await SecurityEvent.create({
            eventType,
            actorToken: tokenizeValue(username),
            sourceIpToken: tokenizeValue(req.ip || ''),
            userAgentToken: tokenizeValue(req.get('user-agent') || ''),
            outcome,
        });
    } catch (error) {
        // Continue request flow if event persistence fails.
    }
}

async function loginHandler(req, res) {
    const username = String(req.body.username || '').trim();
    const password = String(req.body.password || '');

    if (username === '' || password === '') {
        await recordSecurityEvent('login_attempt', username, req, 'missing_fields');
        return res.status(400).json({ error: 'Username and password are required.' });
    }

    if (username !== DEMO_USERNAME || password !== DEMO_PASSWORD) {
        await recordSecurityEvent('login_attempt', username, req, 'invalid_credentials');
        return res.status(401).json({ error: 'Invalid credentials.' });
    }

    const token = jwt.sign(
        {
            sub: DEMO_USER_ID,
            username: DEMO_USERNAME,
            role: 'customer',
        },
        JWT_SECRET,
        {
            expiresIn: JWT_EXPIRES_IN,
            issuer: 'modernbank-backend',
            audience: 'modernbank-frontend',
        }
    );

    await recordSecurityEvent('login_attempt', username, req, 'success');

    return res.json({
        accessToken: token,
        tokenType: 'Bearer',
        expiresIn: JWT_EXPIRES_IN,
        user: {
            id: DEMO_USER_ID,
            username: DEMO_USERNAME,
            role: 'customer',
            name: 'Julia Ross',
        },
    });
}

app.post('/api/auth/login', loginHandler);
app.post('/api/authenticate', loginHandler);

app.get('/api/auth/me', requireJwt, (req, res) => {
    return res.json({
        id: req.auth.userId,
        username: req.auth.username,
        role: req.auth.role,
        tier: 'Platinum',
    });
});

app.get('/api/health', (req, res) => {
    return res.json({
        status: 'ok',
        service: 'modernbank-backend',
        transport: 'tls',
        timestamp: new Date().toISOString(),
    });
});

app.get('/api/db-status', (req, res) => {
    const readyState = mongoose.connection.readyState;
    const databaseReachable = readyState === 1;

    return res.json({
        backend_status: 'ok',
        database_reachable: databaseReachable,
        mongo_ready_state: readyState,
        mongo_transport: 'tls',
        checked_at: new Date().toISOString(),
    });
});

app.get('/api/records', requireJwt, async (req, res) => {
    const records = await SecureRecord.find({ userId: req.auth.userId })
        .sort({ createdAt: -1 })
        .limit(100)
        .lean();

    const response = records.map((item) => ({
        id: String(item._id),
        label: item.label,
        accountLast4: item.accountLast4,
        accountToken: item.accountToken,
        noteToken: item.noteToken,
        createdAt: item.createdAt,
    }));

    return res.json({ records: response });
});

app.post('/api/records', requireJwt, async (req, res) => {
    const label = String(req.body.label || '').trim();
    const accountNumber = String(req.body.accountNumber || '').trim();
    const note = String(req.body.note || '').trim();

    if (label.length < 3 || label.length > 120) {
        return res.status(400).json({ error: 'Label must be between 3 and 120 characters.' });
    }

    if (accountNumber.length < 8 || accountNumber.length > 32) {
        return res.status(400).json({ error: 'Account number must be between 8 and 32 characters.' });
    }

    if (note.length > 256) {
        return res.status(400).json({ error: 'Note length exceeds 256 characters.' });
    }

    const accountDigits = accountNumber.replace(/\D/g, '');
    if (accountDigits.length < 4) {
        return res.status(400).json({ error: 'Account number is invalid.' });
    }

    const secureRecord = await SecureRecord.create({
        userId: req.auth.userId,
        label,
        accountToken: tokenizeValue(accountNumber),
        accountLast4: accountDigits.slice(-4),
        noteToken: tokenizeValue(note),
    });

    return res.status(201).json({
        id: String(secureRecord._id),
        label: secureRecord.label,
        accountLast4: secureRecord.accountLast4,
        accountToken: secureRecord.accountToken,
        noteToken: secureRecord.noteToken,
        createdAt: secureRecord.createdAt,
    });
});

app.get('/api/tokenization/example', requireJwt, (req, res) => {
    const sample = '4111-1111-1111-1111';
    return res.json({
        sample,
        tokenized: tokenizeValue(sample),
    });
});

app.use((err, req, res, next) => {
    if (err && err.message === 'Origin not allowed') {
        return res.status(403).json({ error: 'Origin not allowed.' });
    }

    if (err && err.name === 'SyntaxError') {
        return res.status(400).json({ error: 'Invalid JSON payload.' });
    }

    return res.status(500).json({ error: 'Internal server error.' });
});

async function connectMongo() {
    const connectOptions = {
        tls: true,
        maxPoolSize: parseNumber(process.env.MONGO_MAX_POOL_SIZE || '10', 10),
        serverSelectionTimeoutMS: parseNumber(
            process.env.MONGO_SERVER_SELECTION_TIMEOUT_MS || '8000',
            8000
        ),
    };

    if (MONGO_TLS_CA_FILE !== '') {
        connectOptions.tlsCAFile = MONGO_TLS_CA_FILE;
    }

    if (MONGO_TLS_ALLOW_INVALID_CERTS) {
        connectOptions.tlsAllowInvalidCertificates = true;
    }

    await mongoose.connect(MONGO_URI, connectOptions);
}

async function startServer() {
    if (!fs.existsSync(TLS_CERT_PATH) || !fs.existsSync(TLS_KEY_PATH)) {
        throw new Error(
            `TLS certificate files not found. Expected cert=${TLS_CERT_PATH} key=${TLS_KEY_PATH}`
        );
    }

    await connectMongo();

    const tlsOptions = {
        cert: fs.readFileSync(TLS_CERT_PATH),
        key: fs.readFileSync(TLS_KEY_PATH),
        minVersion: 'TLSv1.2',
    };

    https.createServer(tlsOptions, app).listen(PORT, () => {
        console.log('Modern Bank secure backend started (HTTPS only).');
        console.log(`TLS API listening on port ${PORT}`);
    });
}

if (require.main === module) {
    startServer().catch((error) => {
        console.error('Backend startup failed:', error.message);
        process.exit(1);
    });
}

module.exports = {
    app,
    startServer,
    tokenizeValue,
};
