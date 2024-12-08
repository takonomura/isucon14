<?php

declare(strict_types=1);

namespace IsuRide\Handlers\App;

use Fig\Http\Message\StatusCodeInterface;
use IsuRide\Database\Model\User;
use IsuRide\Handlers\AbstractHttpHandler;
use IsuRide\Model\AppPostPaymentMethodsRequest;
use IsuRide\Response\ErrorResponse;
use PDO;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Slim\Exception\HttpBadRequestException;

class PostPaymentMethods extends AbstractHttpHandler
{
    public function __construct(
        private readonly PDO $db,
    ) {
    }

    /**
     * @param ServerRequestInterface $request
     * @param ResponseInterface $response
     * @param array<string, string> $args
     * @return ResponseInterface
     */
    public function __invoke(
        ServerRequestInterface $request,
        ResponseInterface $response,
        array $args
    ): ResponseInterface {
        $req = new AppPostPaymentMethodsRequest((array)$request->getParsedBody());
        if (!$req->valid()) {
            return (new ErrorResponse())->write(
                $response,
                StatusCodeInterface::STATUS_BAD_REQUEST,
                new HttpBadRequestException(
                    request: $request,
                    message: 'required fields(token) are null'
                )
            );
        }
        $token = $req->getToken();
        if ($token === '') {
            return (new ErrorResponse())->write(
                $response,
                StatusCodeInterface::STATUS_BAD_REQUEST,
                new HttpBadRequestException(
                    request: $request,
                    message: 'token is required but was empty'
                )
            );
        }
        $user = $request->getAttribute('user');
        assert($user instanceof User);
        try {
            $stmt = $this->db->prepare('INSERT INTO payment_tokens (user_id, token) VALUES (?, ?)');
            $stmt->execute([$user->id, $token]);
            return $this->writeNoContent($response);
        } catch (\PDOException $e) {
            return (new ErrorResponse())->write(
                $response,
                StatusCodeInterface::STATUS_INTERNAL_SERVER_ERROR,
                $e
            );
        }
    }
}
