import { getCookie } from "hono/cookie";
import { createMiddleware } from "hono/factory";
import type { RowDataPacket } from "mysql2/promise";
import type { Environment } from "./types/hono.js";
import type { Chair, Owner, User } from "./types/models.js";

export const appAuthMiddleware = createMiddleware<Environment>(
  async (ctx, next) => {
    const accessToken = getCookie(ctx, "app_session");
    if (!accessToken) {
      return ctx.text("app_session cookie is required", 401);
    }
    try {
      const [[user]] = await ctx.var.dbConn.query<Array<User & RowDataPacket>>(
        "SELECT * FROM users WHERE access_token = ?",
        [accessToken],
      );
      if (!user) {
        return ctx.text("invalid access token", 401);
      }
      ctx.set("user", user);
    } catch (error) {
      return ctx.text(`Internal Server Error\n${error}`, 500);
    }
    await next();
  },
);

export const ownerAuthMiddleware = createMiddleware<Environment>(
  async (ctx, next) => {
    const accessToken = getCookie(ctx, "owner_session");
    if (!accessToken) {
      return ctx.text("owner_session cookie is required", 401);
    }
    try {
      const [[owner]] = await ctx.var.dbConn.query<
        Array<Owner & RowDataPacket>
      >("SELECT * FROM owners WHERE access_token = ?", [accessToken]);
      if (!owner) {
        return ctx.text("invalid access token", 401);
      }
      ctx.set("owner", owner);
    } catch (error) {
      return ctx.text(`Internal Server Error\n${error}`, 500);
    }
    await next();
  },
);

export const chairAuthMiddleware = createMiddleware<Environment>(
  async (ctx, next) => {
    const accessToken = getCookie(ctx, "chair_session");
    if (!accessToken) {
      return ctx.text("chair_session cookie is required", 401);
    }
    try {
      const [[chair]] = await ctx.var.dbConn.query<
        Array<Chair & RowDataPacket>
      >("SELECT * FROM chairs WHERE access_token = ?", [accessToken]);
      if (!chair) {
        return ctx.text("invalid access token", 401);
      }
      ctx.set("chair", chair);
    } catch (error) {
      return ctx.text(`Internal Server Error\n${error}`, 500);
    }
    await next();
  },
);
