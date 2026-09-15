import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export const CHAT_SESSION_EXTENSION_MINUTES = [5, 10, 15, 30] as const;
export type ChatSessionExtensionMinutes =
  (typeof CHAT_SESSION_EXTENSION_MINUTES)[number];

export class ExtendChatSessionDto {
  @IsInt()
  @IsIn([...CHAT_SESSION_EXTENSION_MINUTES])
  minutes: ChatSessionExtensionMinutes;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  idempotencyKey: string;
}
