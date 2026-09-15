import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { AuditService } from '../../audit/audit.service';
import { AuditAction } from '../../audit/entities/audit-log.entity';
import { Request } from 'express';

interface AuditLogContext {
  action: AuditAction;
  getTargetUserId: (request: Request) => number | undefined;
  getOldData?: (request: Request) => Record<string, any>;
  getNewData?: (request: Request) => Record<string, any>;
}

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AuditInterceptor.name);

  constructor(
    private readonly auditService: AuditService,
    private readonly context: AuditLogContext,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest<Request>();
    const user = request.user as any;

    if (!user) {
      return next.handle();
    }

    const targetUserId = this.context.getTargetUserId(request);
    if (!targetUserId) {
      return next.handle();
    }

    return next.handle().pipe(
      tap(async () => {
        try {
          const oldData = this.context.getOldData?.(request) || {};
          const newData = this.context.getNewData?.(request) || {};
          const ipAddress = this.extractIpAddress(request);

          await this.auditService.createLog(
            user.id,
            targetUserId,
            this.context.action,
            oldData,
            newData,
            ipAddress,
          );

          this.logger.log(
            `Audit log created: ${this.context.action} by user ${user.id} on user ${targetUserId}`,
          );
        } catch (error) {
          this.logger.error(`Failed to create audit log: ${error.message}`);
        }
      }),
    );
  }

  private extractIpAddress(request: Request): string {
    const xForwardedFor = request.headers['x-forwarded-for'];
    if (xForwardedFor) {
      return (xForwardedFor as string).split(',')[0].trim();
    }
    return request.socket.remoteAddress || 'unknown';
  }
}

// Factory function to create interceptor with context
export const AuditInterceptorFactory = (context: AuditLogContext) => {
  return {
    provide: 'AUDIT_INTERCEPTOR',
    useFactory: (auditService: AuditService) => {
      return new AuditInterceptor(auditService, context);
    },
    inject: [AuditService],
  };
};
