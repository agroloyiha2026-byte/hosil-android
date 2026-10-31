export type VerifiedPaymentEvent = {
  eventId: string;
  transactionId: string;
  providerReference: string;
  amountMinor: bigint;
  currency: "UZS" | "USD";
  outcome: "authorized" | "captured" | "refunded" | "failed";
};

export interface PaymentProvider {
  verifyWebhook(request: Request, rawBody: Uint8Array): Promise<VerifiedPaymentEvent>;
}
