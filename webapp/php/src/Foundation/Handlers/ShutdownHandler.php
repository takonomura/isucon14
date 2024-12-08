<?php

declare(strict_types=1);

namespace IsuRide\Foundation\Handlers;

use IsuRide\Foundation\ResponseEmitter\ResponseEmitter;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Exception\HttpInternalServerErrorException;

readonly class ShutdownHandler
{
    public function __construct(
        private Request $request,
        private HttpErrorHandler $errorHandler,
        private bool $displayErrorDetails
    ) {
    }

    public function __invoke(): void
    {
        $error = error_get_last();
        if (!$error) {
            return;
        }

        $message = $this->getErrorMessage($error);
        $exception = new HttpInternalServerErrorException($this->request, $message);
        $response = $this->errorHandler->__invoke(
            $this->request,
            $exception,
            $this->displayErrorDetails,
            false,
            false,
        );

        $responseEmitter = new ResponseEmitter();
        $responseEmitter->emit($response);
    }

    private function getErrorMessage(array $error): string
    {
        if (!$this->displayErrorDetails) {
            return 'An error while processing your request. Please try again later.';
        }

        $errorFile = $error['file'];
        $errorLine = $error['line'];
        $errorMessage = $error['message'];
        $errorType = $error['type'];

        if ($errorType === E_USER_ERROR) {
            return "FATAL ERROR: $errorMessage. on line $errorLine in file $errorFile.";
        }

        if ($errorType === E_USER_WARNING) {
            return "WARNING: $errorMessage";
        }

        if ($errorType === E_USER_NOTICE) {
            return "NOTICE: $errorMessage";
        }

        return "FATAL ERROR: $errorMessage. on line $errorLine in file $errorFile.";
    }
}
