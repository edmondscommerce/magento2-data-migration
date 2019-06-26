<?php declare(strict_types=1);

namespace Edmondscommerce\MagentoMigration;

class Select
{
    /**
     * @var string
     */
    private $dbName;
    /**
     * @var string
     */
    private $host;
    /**
     * @var string
     */
    private $user;
    /**
     * @var string
     */
    private $pass;
    /**
     * @var PDO
     */
    private $pdo;

    public function __construct(string $configPath)
    {
        try {
            $this->extractDbConfig($configPath);

            $this->pdo = new PDO("mysql:dbname={$this->dbName};host={$this->host}", $this->user, $this->pass);
            $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        } catch (\PDOException $e) {
            echo "Unable to setup connection to database\n";
            echo $e->getMessage() . "\n";
            return;
        }
    }

    public function execute(string $query, array $params): array
    {
        $this->assertIsValidQuery($query);

        return $this->pdo
            ->query($query)
            ->execute($params)
            ->fetchAll();
    }

    private function extractDbConfig(string $configPath): void
    {
        if (false === file_exists($configPath)) {
            throw new \InvalidArgumentException(
                "No config.xml file found at '$configPath'"
            );
        }

        $xml = simplexml_load_file($configPath);

        if (false === $xml) {
            throw new \InvalidArgumentException(
                "Unable to load config from '$configPath'"
            );
        }

        /** @var SimpleXMLElement $xml */

        $this->host   = $xml->source['host'];
        $this->dbName = $xml->source['name'];
        $this->user   = $xml->source['user'];
        $this->pass   = $xml->source['password'];
    }

    private function assertIsValidQuery(string $query): void
    {
        $upperQuery = strtoupper($query);

        $isInsert = false !== strpos($upperQuery, 'INSERT');
        $isUpdate = false !== strpos($upperQuery, 'UPDATE');
        $isDelete = false !== strpos($upperQuery, 'DELETE');

        if ($isInsert || $isUpdate || $isDelete) {
            throw new \InvalidArgumentException(
                "Only SELECT queries allowed: '$query'"
            );
        }
    }
}