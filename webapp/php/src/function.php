<?php

declare(strict_types=1);

function secureRandomStr(int $b): string
{
    try {
        $k = random_bytes($b);
    } catch (Exception $e) {
        throw new RuntimeException('Failed to generate secure random bytes', 0, $e);
    }
    return bin2hex($k);
}
