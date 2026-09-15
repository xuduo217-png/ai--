import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from "class-validator";
import { PaginationDto } from "../../common/dto/pagination.dto";
import {
  AfterSaleHandlerType,
  AfterSaleStatus,
  AfterSaleType,
  ArbitrationDecision,
} from "../entities/order-after-sale.entity";
import { OrderType } from "../entities/order.entity";

export class CreateAfterSaleItemDto {
  @IsString()
  @MaxLength(80)
  lineKey: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity: number;
}

export class CreateAfterSaleDto {
  @IsOptional()
  @IsEnum(AfterSaleType)
  afterSaleType?: AfterSaleType;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateAfterSaleItemDto)
  items?: CreateAfterSaleItemDto[];

  @IsString()
  @MaxLength(50)
  reasonCode: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(9)
  @IsString({ each: true })
  evidenceUrls?: string[];
}

export class SellerApproveAfterSaleDto {
  @IsOptional()
  @IsBoolean()
  returnRequired?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  returnAddress?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reason?: string;
}

export class SellerRejectAfterSaleDto {
  @IsString()
  @MaxLength(1000)
  reason: string;
}

export class SubmitReturnDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  trackingNumber?: string | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(9)
  @IsString({ each: true })
  evidenceUrls?: string[];
}

export class ApplyArbitrationDto {
  @IsString()
  @MaxLength(2000)
  reason: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(9)
  @IsString({ each: true })
  evidenceUrls?: string[];
}

export class AdminArbitrateAfterSaleDto {
  @IsEnum(ArbitrationDecision)
  decision: ArbitrationDecision;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  remark?: string;
}

export enum AdminAfterSaleDecision {
  APPROVE = "approve",
  REJECT = "reject",
}

export class AdminApprovedAfterSaleItemDto {
  @IsString()
  @MaxLength(80)
  lineKey: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity: number;
}

export class AdminReviewAfterSaleDto {
  @IsEnum(AdminAfterSaleDecision)
  decision: AdminAfterSaleDecision;

  @IsOptional()
  @IsEnum(AfterSaleType)
  afterSaleType?: AfterSaleType;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AdminApprovedAfterSaleItemDto)
  approvedItems?: AdminApprovedAfterSaleItemDto[];

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  reason?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  returnAddress?: string;
}

export class AdminConfirmReturnItemDto {
  @IsString()
  @MaxLength(80)
  lineKey: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  restockQuantity: number;
}

export class AdminConfirmReturnDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AdminConfirmReturnItemDto)
  items: AdminConfirmReturnItemDto[];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  remark?: string;
}

export class QueryAfterSaleDto extends PaginationDto {
  @IsOptional()
  @IsEnum(AfterSaleStatus)
  status?: AfterSaleStatus;

  @IsOptional()
  @IsEnum(OrderType)
  orderType?: OrderType;

  @IsOptional()
  @IsEnum(AfterSaleHandlerType)
  handlerType?: AfterSaleHandlerType;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  productId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  buyerId?: number;

  @IsOptional()
  @IsIn(["true", "false"])
  overdue?: "true" | "false";

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  orderId?: number;

  @IsOptional()
  @IsString()
  keyword?: string;

  @IsOptional()
  @IsString()
  @IsIn([
    "pending",
    "platform_pending",
    "second_hand_arbitration",
    "processing",
    "finished",
    "all",
  ])
  view?:
    | "pending"
    | "platform_pending"
    | "second_hand_arbitration"
    | "processing"
    | "finished"
    | "all";

  @IsOptional()
  @IsDateString()
  createdFrom?: string;

  @IsOptional()
  @IsDateString()
  createdTo?: string;
}

export class ShipSecondHandOrderDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  trackingNumber?: string;
}

export class UpdateSecondHandTrackingDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  trackingNumber?: string | null;
}
