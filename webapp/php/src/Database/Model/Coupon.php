<?php

declare(strict_types=1);

namespace IsuRide\Database\Model;

readonly class Coupon
{
    public function __construct(
        public string $userId,
        public string $code,
        public int $discount,
        public string $createdAt,
        public ?string $usedBy
    ) {
    }
}
