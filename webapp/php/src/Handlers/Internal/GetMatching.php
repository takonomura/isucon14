<?php

declare(strict_types=1);

namespace IsuRide\Handlers\Internal;

use IsuRide\Handlers\AbstractHttpHandler;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use PDO;

// このAPIをインスタンス内から一定間隔で叩かせることで、椅子とライドをマッチングさせる
class GetMatching extends AbstractHttpHandler
{
    public function __construct(
        private readonly PDO $db,
    ) {
    }

    public function __invoke(
        ServerRequestInterface $request,
        ResponseInterface $response,
    ): ResponseInterface {
        // MEMO: 一旦最も待たせているリクエストに適当な空いている椅子マッチさせる実装とする。おそらくもっといい方法があるはず…
        $stmt = $this->db->prepare('SELECT * FROM rides WHERE chair_id IS NULL ORDER BY created_at LIMIT 1');
        $stmt->execute();
        $ride = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$ride) {
            return $this->writeNoContent($response);
        }
        for ($i = 0; $i < 10; $i++) {
            $stmt = $this->db->prepare(
                'SELECT * FROM chairs INNER JOIN (SELECT id FROM chairs WHERE is_active = TRUE ORDER BY RAND() LIMIT 1) AS tmp ON chairs.id = tmp.id LIMIT 1'
            );
            $stmt->execute();
            $matched = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$matched) {
                return $this->writeNoContent($response);
            }
            $stmt = $this->db->prepare(
                'SELECT COUNT(*) = 0 FROM (SELECT COUNT(chair_sent_at) = 6 AS completed FROM ride_statuses WHERE ride_id IN (SELECT id FROM rides WHERE chair_id = ?) GROUP BY ride_id) is_completed WHERE completed = FALSE'
            );
            $stmt->execute([$matched['id']]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            $empty = $result['COUNT(*) = 0'];
            if ($empty) {
                break;
            }
        }
        if (!$empty) {
            return $this->writeNoContent($response);
        }
        $stmt = $this->db->prepare('UPDATE rides SET chair_id = ? WHERE id = ?');
        $stmt->execute([$matched['id'], $ride['id']]);
        return $this->writeNoContent($response);
    }
}
