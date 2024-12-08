import type { PoolConnection } from "mysql2/promise";
import type { Chair, Owner, User } from "./models.js";

export type Environment = {
  Variables: {
    dbConn: PoolConnection;
    user: User;
    owner: Owner;
    chair: Chair;
  };
};
