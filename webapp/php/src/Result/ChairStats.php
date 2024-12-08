<?php

declare(strict_types=1);

namespace IsuRide\Result;

use IsuRide\Model\UserNotificationDataChairStats;
use Throwable;

readonly class ChairStats
{
    /**
     * @param UserNotificationDataChairStats $stats
     * @param Throwable|null $error
     */
    public function __construct(
        public UserNotificationDataChairStats $stats,
        public ?Throwable $error = null
    ) {
    }

    public function isError(): bool
    {
        return $this->error !== null;
    }
}
