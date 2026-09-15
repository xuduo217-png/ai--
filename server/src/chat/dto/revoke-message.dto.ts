import { IsNotEmpty, IsString } from "class-validator";

export class RevokeChatMessageDto {
  @IsString()
  @IsNotEmpty()
  conversationId: string;
}
