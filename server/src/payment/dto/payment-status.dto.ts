import {
  BusinessType,
  PaymentChannel,
  PaymentMethod,
  PaymentStatus,
} from "../entities/payment.entity";

export interface PaymentStatusResponseDto {
  paymentNo: string;
  status: PaymentStatus;
  channel: PaymentChannel;
  method: PaymentMethod;
  amount: number;
  refundAmount: number;
  businessType: BusinessType;
  paidAt: Date | null;
  closedAt: Date | null;
  expiredAt: Date | null;
}
