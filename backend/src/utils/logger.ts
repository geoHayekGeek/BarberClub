/**
 * Structured logger module with levels
 * Defaults to silent in production unless LOG_LEVEL is set
 */

export enum LogLevel {
  ERROR = 0,
  WARN = 1,
  INFO = 2,
  DEBUG = 3,
}

interface LogEntry {
  level: string;
  message: string;
  timestamp: string;
  [key: string]: unknown;
}

class Logger {
  private level: number;
  private isProduction: boolean;

  constructor() {
    this.isProduction = process.env.NODE_ENV === 'production';
    const envLevel = process.env.LOG_LEVEL?.toLowerCase() || 'silent';
    
    if (this.isProduction && envLevel === 'silent') {
      this.level = -1; // Silent
    } else {
      switch (envLevel) {
        case 'error':
          this.level = LogLevel.ERROR;
          break;
        case 'warn':
          this.level = LogLevel.WARN;
          break;
        case 'info':
          this.level = LogLevel.INFO;
          break;
        case 'debug':
          this.level = LogLevel.DEBUG;
          break;
        default:
          this.level = this.isProduction ? -1 : LogLevel.INFO;
      }
    }
  }

  private shouldLog(level: LogLevel): boolean {
    return level <= this.level;
  }

  private formatMessage(level: string, message: string, meta?: Record<string, unknown>): LogEntry {
    const entry: LogEntry = {
      level,
      message,
      timestamp: new Date().toISOString(),
    };

    if (meta) {
      Object.assign(entry, meta);
    }

    return entry;
  }

  private log(level: LogLevel, levelName: string, message: string, meta?: Record<string, unknown>): void {
    if (!this.shouldLog(level)) {
      return;
    }

    const entry = this.formatMessage(levelName, message, meta);
    const jsonString = JSON.stringify(entry);

    if (level === LogLevel.ERROR) {
      process.stderr.write(jsonString + '\n');
    } else {
      process.stdout.write(jsonString + '\n');
    }
  }

  error(message: string, meta?: Record<string, unknown>): void {
    this.log(LogLevel.ERROR, 'ERROR', message, meta);
  }

  warn(message: string, meta?: Record<string, unknown>): void {
    this.log(LogLevel.WARN, 'WARN', message, meta);
  }

  info(message: string, meta?: Record<string, unknown>): void {
    this.log(LogLevel.INFO, 'INFO', message, meta);
  }

  debug(message: string, meta?: Record<string, unknown>): void {
    this.log(LogLevel.DEBUG, 'DEBUG', message, meta);
  }
}

export const logger = new Logger();
