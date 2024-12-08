<?php

declare(strict_types=1);

namespace IsuRide\PaymentGateway;

readonly class GetPaymentsResponseOne
{
    public function __construct(
        public int $amount,
        public string $status
    ) {
    }
}
