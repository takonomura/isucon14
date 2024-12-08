<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

readonly class PaymentToken
{
    public function __construct(
        public string $userId,
        public string $token,
        public string $createdAt
    ) {
    }
}
