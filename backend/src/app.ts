/**
 * Express application setup
 */

import express, { Express } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import swaggerUi from 'swagger-ui-express';
import swaggerJsdoc from 'swagger-jsdoc';
import config from './config';
import routes from './routes';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFoundHandler';
import { generalLimiter } from './middleware/rateLimit';
import path from 'path';
import fs from 'fs';

const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Barber Club API',
      version: '1.0.0',
      description: 'Production backend API for Barber Club mobile app',
    },
    servers: [
      {
        url: `http://localhost:${config.PORT}`,
        description: 'Development server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        ErrorResponse: {
          type: 'object',
          properties: {
            error: {
              type: 'object',
              properties: {
                code: {
                  type: 'string',
                  description: 'Error code',
                },
                message: {
                  type: 'string',
                  description: 'Human-readable error message',
                },
                fields: {
                  type: 'object',
                  description: 'Field-specific validation errors',
                  additionalProperties: {
                    type: 'string',
                  },
                },
              },
              required: ['code', 'message'],
            },
          },
          required: ['error'],
        },
      },
    },
  },
  apis: ['./dist/routes/*.js', './src/routes/*.ts'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

export function createApp(): Express {
  const app = express();

  // Railway / reverse proxies set X-Forwarded-* headers. Enable trust proxy in production
  // so express-rate-limit can correctly identify the client IP.
  if (config.NODE_ENV === 'production') {
    app.set('trust proxy', 1);
  }

  // Allow app clients (and potential web frontends) to load static assets from /images.
  // Default Helmet sets Cross-Origin-Resource-Policy: same-origin, which can block
  // loading images/videos when the consuming app is on a different origin.
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );
  
  app.use(cors({
    origin: config.CORS_ORIGINS,
    credentials: true,
  }));

  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Serve images: IMAGES_PATH env, or cwd/public/images (when run from backend), or __dirname-based
  const fromCwd = path.join(process.cwd(), 'public', 'images');
  const fromDirname = path.resolve(__dirname, '..', '..', 'public', 'images');
  const imagesPath =
    process.env.IMAGES_PATH ||
    (fs.existsSync(fromCwd) ? fromCwd : fromDirname);
  app.use(
    '/images',
    express.static(imagesPath, {
      setHeaders: (res) => {
        res.setHeader('Access-Control-Allow-Origin', '*');
      },
    }),
  );
  if (config.NODE_ENV !== 'test') {
    const exists = fs.existsSync(imagesPath);
    // eslint-disable-next-line no-console
    console.log('[images] path:', imagesPath, 'exists:', exists);
  }

  if (config.NODE_ENV !== 'test') {
    app.use(generalLimiter);
  }

  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

  app.use('/api/v1', routes);

  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  app.set('imagesPath', imagesPath);
  // Debug: verify images path exists and list sample files
  app.get('/debug/images', (_req, res) => {
    const resolvedPath = (app.get('imagesPath') as string) || imagesPath;
    try {
      const exists = fs.existsSync(resolvedPath);
      const entries = exists ? fs.readdirSync(resolvedPath, { withFileTypes: true }) : [];
      const files = entries.map((d) => (d.isDirectory() ? `${d.name}/` : d.name)).slice(0, 20);
      res.json({ imagesPath: resolvedPath, exists, files, cwd: process.cwd() });
    } catch (e) {
      res.status(500).json({ imagesPath: resolvedPath, error: String(e), cwd: process.cwd() });
    }
  });

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
