<?php
    $servername = getenv('DB_SERVERNAME') ?: 'mysql-db';
    $username = getenv('DB_USERNAME') ?: 'root';
    $password = getenv('DB_PASSWORD') ?: 'motdepasse';
    $dbname = getenv('DB_NAME') ?: 'ma_base_de_donnees';
    $redis_host = getenv('REDIS_HOST') ?: 'redis';
    $redis_port = getenv('REDIS_PORT') ?: 6379;
    $cached = "dans bd";

    // Connexion à MySQL
    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }

    // Connexion à Redis
    $redis = new Redis();
    $redis->connect($redis_host, $redis_port);

    // Vérifier si les données sont en cache
    $cachedData = $redis->get("utilisateurs");
    if ($cachedData) {
        $utilisateurs = json_decode($cachedData, true);
        $cached = "dans cache";
    } else {
        $sql = "SELECT * FROM utilisateurs";
        $result = $conn->query($sql);

        $utilisateurs = [];
        if ($result->num_rows > 0) {
            while($row = $result->fetch_assoc()) {
                $utilisateurs[] = $row;
            }
        }

        // Mettre en cache les résultats pendant 60 secondes
        $redis->set("utilisateurs", json_encode($utilisateurs), 60);
    }

    // Afficher les utilisateurs
    echo "<h1>Liste des utilisateurs ".$cached." </h1><ul>";
    foreach ($utilisateurs as $user) {
        echo "<li>" . $user["nom"] . " - " . $user["email"] . "</li>";
    }
    echo "</ul>";

    $conn->close();
?>