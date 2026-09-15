import { EntityManager } from "typeorm";
import { Payment } from "./entities/payment.entity";

export const CHAT_PAYMENT_FULFILLER = "CHAT_PAYMENT_FULFILLER";

export type PaymentAfterCommit = () => Promise<void>;

export interface ChatPaymentFulfiller {
  fulfillSuccessfulPayment(
    manager: EntityManager,
    payment: Payment,
  ): Promise<PaymentAfterCommit | void>;
}
