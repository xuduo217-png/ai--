import { Injectable, Logger, UnauthorizedException } from "@nestjs/common";
import { randomUUID } from "crypto";
import { Socket } from "socket.io";
import { RedisService } from "../redis/redis.service";

/**
 * 认证主体类型
 */
export type AuthSessionPrincipalType = "user" | "doctor";

/**
 * 已注册的 WebSocket 连接信息
 */
interface RegisteredSocket {
  sid: string;
  socket: Pick<Socket, "id" | "emit" | "disconnect">;
  namespace: string;
}

/**
 * 认证会话管理服务
 * 业务规则：同一账号同一时刻只允许一个活跃 sid，新登录会立即顶掉旧 sid。
 */
@Injectable()
export class AuthSessionService {
  private readonly logger = new Logger(AuthSessionService.name);
  private readonly socketRegistry = new Map<
    string,
    Map<string, RegisteredSocket>
  >();

  constructor(private readonly redisService: RedisService) {}

  /**
   * 签发新的活跃会话 sid
   */
  async issueSession(
    type: AuthSessionPrincipalType,
    principalId: number,
  ): Promise<string> {
    const sid = randomUUID();
    const key = this.buildSessionKey(type, principalId);

    await this.redisService.set(key, sid);
    this.disconnectStaleSockets(type, principalId, sid, "账号已在其他设备登录");

    return sid;
  }

  /**
   * 校验 sid 是否为当前活跃会话
   */
  async isSessionActive(
    type: AuthSessionPrincipalType,
    principalId: number,
    sid?: string,
  ): Promise<boolean> {
    if (!sid) {
      return false;
    }

    const currentSid = await this.redisService.get(
      this.buildSessionKey(type, principalId),
    );
    return Boolean(currentSid && currentSid === sid);
  }

  /**
   * 强校验当前 sid
   */
  async assertSession(
    type: AuthSessionPrincipalType,
    principalId: number,
    sid?: string,
  ): Promise<void> {
    const isActive = await this.isSessionActive(type, principalId, sid);
    if (!isActive) {
      throw new UnauthorizedException("账号已在其他设备登录，请重新登录");
    }
  }

  /**
   * 注册 WebSocket 连接
   * 业务规则：允许同一 sid 在多个命名空间建立连接，但要清理同账号旧 sid 的残留连接。
   */
  registerSocket(
    type: AuthSessionPrincipalType,
    principalId: number,
    sid: string,
    socket: Pick<Socket, "id" | "emit" | "disconnect">,
    namespace: string,
  ): void {
    const principalKey = this.buildPrincipalRegistryKey(type, principalId);
    const sockets =
      this.socketRegistry.get(principalKey) ??
      new Map<string, RegisteredSocket>();

    sockets.set(socket.id, {
      sid,
      socket,
      namespace,
    });
    this.socketRegistry.set(principalKey, sockets);

    this.disconnectStaleSockets(type, principalId, sid, "账号已在其他设备登录");
  }

  /**
   * 注销 WebSocket 连接
   */
  unregisterSocket(
    type: AuthSessionPrincipalType,
    principalId: number,
    socketId: string,
  ): void {
    const principalKey = this.buildPrincipalRegistryKey(type, principalId);
    const sockets = this.socketRegistry.get(principalKey);
    if (!sockets) {
      return;
    }

    sockets.delete(socketId);
    if (sockets.size === 0) {
      this.socketRegistry.delete(principalKey);
    }
  }

  /**
   * 撤销当前活跃会话
   * 业务规则：显式退出登录时应清掉当前 sid，并主动断开该 sid 下的连接，避免“本地退出但服务端仍有效”。
   */
  async revokeSession(
    type: AuthSessionPrincipalType,
    principalId: number,
    sid?: string,
  ): Promise<void> {
    const key = this.buildSessionKey(type, principalId);
    const currentSid = await this.redisService.get(key);

    if (!currentSid) {
      return;
    }

    if (sid && currentSid !== sid) {
      return;
    }

    await this.redisService.del(key);
    this.disconnectTargetSockets(
      type,
      principalId,
      currentSid,
      "当前账号已退出登录",
    );
  }

  /**
   * 断开同账号旧 sid 的连接
   */
  private disconnectStaleSockets(
    type: AuthSessionPrincipalType,
    principalId: number,
    activeSid: string,
    reason: string,
  ): void {
    const principalKey = this.buildPrincipalRegistryKey(type, principalId);
    const sockets = this.socketRegistry.get(principalKey);
    if (!sockets || sockets.size === 0) {
      return;
    }

    sockets.forEach((entry, socketId) => {
      if (entry.sid === activeSid) {
        return;
      }

      this.logger.warn(
        `[AuthSession] 断开旧会话连接: ${type}#${principalId}, namespace=${entry.namespace}, socketId=${socketId}`,
      );

      entry.socket.emit("auth:session:revoked", { reason });
      entry.socket.disconnect(true);
      sockets.delete(socketId);
    });

    if (sockets.size === 0) {
      this.socketRegistry.delete(principalKey);
    }
  }

  /**
   * 断开指定 sid 的连接
   */
  private disconnectTargetSockets(
    type: AuthSessionPrincipalType,
    principalId: number,
    targetSid: string,
    reason: string,
  ): void {
    const principalKey = this.buildPrincipalRegistryKey(type, principalId);
    const sockets = this.socketRegistry.get(principalKey);
    if (!sockets || sockets.size === 0) {
      return;
    }

    sockets.forEach((entry, socketId) => {
      if (entry.sid !== targetSid) {
        return;
      }

      entry.socket.emit("auth:session:revoked", { reason });
      entry.socket.disconnect(true);
      sockets.delete(socketId);
    });

    if (sockets.size === 0) {
      this.socketRegistry.delete(principalKey);
    }
  }

  /**
   * 构建 Redis 会话键
   */
  private buildSessionKey(
    type: AuthSessionPrincipalType,
    principalId: number,
  ): string {
    return `auth:session:${type}:${principalId}`;
  }

  /**
   * 构建内存注册表键
   */
  private buildPrincipalRegistryKey(
    type: AuthSessionPrincipalType,
    principalId: number,
  ): string {
    return `${type}:${principalId}`;
  }
}
