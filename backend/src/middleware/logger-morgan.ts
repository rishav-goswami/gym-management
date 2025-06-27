/**
 * file: logger.ts
 * This module configures and exports the Morgan logging middleware.
 * It's designed to be imported and used in the main server file.
 */

import express from "express";
import morgan from "morgan";

/**
 * Custom middleware to intercept the response body.
 * This must be used BEFORE the morgan logger in the middleware chain.
 * It captures the response body and attaches it to the `res` object.
 */
export const responseBodyInterceptor = (
  req: express.Request,
  res: express.Response,
  next: express.NextFunction
) => {
  const originalSend = res.send;
  const chunks: Buffer[] = [];

  res.send = function (body) {
    if (body) {
      const chunk = Buffer.isBuffer(body) ? body : Buffer.from(body);
      chunks.push(chunk);
    }
    return originalSend.apply(res, arguments as any);
  };

  res.on("finish", () => {
    const body = Buffer.concat(chunks).toString("utf8");
    // Attach the captured body to a custom property on the response object
    (res as any).body_for_logging = body;
  });

  next();
};

// --- Define Custom Morgan Tokens ---

// Token for the REQUEST body
morgan.token("req-body", (req: express.Request) => {
  if (!req.body || Object.keys(req.body).length === 0) {
    return "{}";
  }
  return JSON.stringify(req.body);
});

// Token for the RESPONSE body
morgan.token("res-body", (req, res: express.Response) => {
  // Retrieve the body from the custom property we added
  const body = (res as any).body_for_logging;
  if (!body) {
    return "{}";
  }
  return body;
});

// --- Create and Export the Morgan Logger Instance ---

// Define the custom format string
const morganFormat =
  "IN :method :url REQ: :req-body >> OUT :status :response-time ms RES: :res-body";

/**
 * The fully configured Morgan logger middleware.
 * This should be used AFTER the `responseBodyInterceptor`.
 */
export const morganLogger = morgan(morganFormat);
