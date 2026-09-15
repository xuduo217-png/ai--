import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class PhoneLocalAuthGuard extends AuthGuard('phone-local') {}
