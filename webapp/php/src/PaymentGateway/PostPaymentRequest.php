<?php

declare(strict_types=1);

namespace IsuRide\PaymentGateway;

use JsonSerializable;

readonly class PostPaymentRequest implements JsonSerializable
{
    public function __construct(
        public int $amount
    ) {
    }

    public function jsonSerialize(): array
    {
        return ['amount' => $this->amount];
    }
}
