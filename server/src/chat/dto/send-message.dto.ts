import {
  IsNotEmpty,
  IsString,
  IsEnum,
  MaxLength,
  IsInt,
  IsOptional,
} from 'class-validator';
import { MessageType } from '../entities/message.entity';

export class SendMessageDto {
  @IsNotEmpty()
  @IsString()
  conversationId: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(2000)
  content: string;

  @IsOptional()
  @IsEnum(MessageType)
  type?: MessageType;

  @IsNotEmpty()
  @IsInt()
  receiverId: number;
}

export class SendAiConsultationDto {
  @IsNotEmpty()
  @IsString()
  conversationId: string;

  @IsNotEmpty()
  @IsInt()
  aiConsultationId: number;

  @IsNotEmpty()
  @IsInt()
  receiverId: number;
}
