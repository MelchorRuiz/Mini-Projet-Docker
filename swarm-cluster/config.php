<?php
// Configuración de MySQL
$db_host = getenv('DB_SERVERNAME') ?: '127.0.0.1';
$db_name = getenv('DB_NAME') ?: 'todo_app';
$db_user = getenv('DB_USERNAME') ?: 'root';
$db_pass = getenv('DB_PASSWORD') ?: 'root';

try {
    $pdo = new PDO("mysql:host=$db_host;port=3306;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Error de conexión a la base de datos: " . $e->getMessage());
}

// Configuración de Redis
$redis_host = getenv('REDIS_HOST') ?: '127.0.0.1';
$redis = new Redis();
$redis->connect($redis_host, 6379);
if (!$redis->ping()) {
    die("No se pudo conectar a Redis.");
}