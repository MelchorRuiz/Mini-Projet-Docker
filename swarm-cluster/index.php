<?php
// Configuration initiale
require 'config.php';

// Fonctions principales

function creerTache($titre, $description) {
    global $pdo, $redis;

    // Insérer dans MySQL
    $stmt = $pdo->prepare("INSERT INTO tasks (title, description) VALUES (?, ?)");
    $stmt->execute([$titre, $description]);
    $taskId = $pdo->lastInsertId();

    // Sauvegarder dans Redis
    $tache = [
        'id' => $taskId,
        'title' => $titre,
        'description' => $description,
        'status' => 'en_attente',
        'created_at' => date('Y-m-d H:i:s')
    ];
    $redis->set("task:$taskId", json_encode($tache));

    // Nettoyer le cache général
    $redis->del('recent_tasks');

    return $tache;
}

function obtenirToutesLesTaches() {
    global $pdo, $redis;

    // Essayer d'obtenir depuis Redis
    $tachesCachees = $redis->get('recent_tasks');
    if ($tachesCachees) {
        return json_decode($tachesCachees, true);
    }

    // Obtenir depuis MySQL
    $stmt = $pdo->query("SELECT * FROM tasks ORDER BY created_at DESC");
    $taches = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Sauvegarder dans Redis
    $redis->set('recent_tasks', json_encode($taches), 300); // Expire après 5 minutes

    return $taches;
}

function mettreAJourStatutTache($taskId, $statut) {
    global $pdo, $redis;

    // Mettre à jour dans MySQL
    $stmt = $pdo->prepare("UPDATE tasks SET status = ? WHERE id = ?");
    $stmt->execute([$statut, $taskId]);

    // Mettre à jour dans Redis
    $cleTache = "task:$taskId";
    if ($redis->exists($cleTache)) {
        $tache = json_decode($redis->get($cleTache), true);
        $tache['status'] = $statut;
        $redis->set($cleTache, json_encode($tache));
    }

    // Nettoyer le cache général
    $redis->del('recent_tasks');
}

function supprimerTache($taskId) {
    global $pdo, $redis;

    // Supprimer dans MySQL
    $stmt = $pdo->prepare("DELETE FROM tasks WHERE id = ?");
    $stmt->execute([$taskId]);

    // Supprimer dans Redis
    $redis->del("task:$taskId");

    // Nettoyer le cache général
    $redis->del('recent_tasks');
}

// Traiter les actions selon la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        $action = $_POST['action'];
        switch ($action) {
            case 'creer':
                $titre = $_POST['titre'];
                $description = $_POST['description'];
                creerTache($titre, $description);
                break;
            case 'mettreAJour':
                $taskId = $_POST['id'];
                $statut = $_POST['statut'];
                mettreAJourStatutTache($taskId, $statut);
                break;
            case 'supprimer':
                $taskId = $_POST['id'];
                supprimerTache($taskId);
                break;
        }
    }
}

// Obtenir toutes les tâches
$taches = obtenirToutesLesTaches();
?>

<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Système de Gestion des Tâches</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
        }
        body { 
            font-family: Arial, sans-serif; 
            margin: 20px; 
            background-color: #1f192f;
        }
        h1 { 
            color: #f0f7da; 
            font-size: 3em;
            text-align: center;
            padding-bottom: 20px;
        }
        label {
            color: #f0f7da;
            font-size: 1.2em;
            display: inline-block;
            margin-top: 10px;

        }
        input[type="text"], textarea {
            width: 100%;
            padding: 10px;
            margin-top: 5px;
            margin-bottom: 10px;
            border: 1px solid #ccc;
            border-radius: 4px;
            box-sizing: border-box;
        }
        form { 
            margin-bottom: 20px; 
        }
        table { 
            width: 80%; 
            height: fit-content;
            border-collapse: collapse; 
            margin-bottom: 20px;
        }
        th, td { 
            padding: 10px; 
            border: 1px solid #ddd; 
            background-color: #b5e8c3; 
        }
        th { 
            background-color: #65b8a6; 
        }
        .terminee { 
            text-decoration: line-through; color: gray; 
        }
        .container {
            display: flex;
            gap: 20px;
            width: 100%;
            height: 85vh;
            padding-top: 20px;
        }
        .form {
            width: 20%;
        }
        .task-btn {
            background-color: #2d6073;
            color: white;
            padding: 14px 20px;
            margin: 8px 0;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            width: 100%;
        }
        .delete-btn {
            background-color: #f44336;
            color: white;
            padding: 8px 10px;
            margin: 8px 0;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        .edit-btn {
            background-color: #2d6073;
            color: white;
            padding: 8px 10px;
            margin: 8px 0;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <h1>Système de Gestion des Tâches Avec MySQL et Redis</h1>
    <div class="container">
        <!-- Formulaire pour créer une nouvelle tâche -->
        <form method="POST" action="" class="form">
            <input type="hidden" name="action" value="creer">
            <label for="titre">Titre :</label>
            <br>
            <input type="text" id="titre" name="titre" required>
            <br>
            <label for="description">Description :</label>
            <br>
            <textarea id="description" name="description"></textarea>
            <br>
            <button type="submit" class="task-btn">Créer une Tâche</button>
        </form>

        <!-- Liste des tâches -->
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Titre</th>
                    <th>Description</th>
                    <th>Statut</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($taches as $tache): ?>
                    <tr>
                        <td><?php echo htmlspecialchars($tache['id']); ?></td>
                        <td class="<?php echo $tache['status'] === 'terminee' ? 'terminee' : ''; ?>">
                            <?php echo htmlspecialchars($tache['title']); ?>
                        </td>
                        <td><?php echo htmlspecialchars($tache['description']); ?></td>
                        <td><?php echo htmlspecialchars($tache['status'] === 'en_attente' ? 'En attente' : 'Terminée'); ?></td>
                        <td>
                            <!-- Formulaire pour mettre à jour le statut -->
                            <form method="POST" style="display:inline;">
                                <input type="hidden" name="action" value="mettreAJour">
                                <input type="hidden" name="id" value="<?php echo htmlspecialchars($tache['id']); ?>">
                                <input type="hidden" name="statut" value="<?php echo $tache['status'] === 'en_attente' ? 'terminee' : 'en_attente'; ?>">
                                <button type="submit" class="edit-btn">Marquer comme <?php echo $tache['status'] === 'en_attente' ? 'Terminée' : 'En Attente'; ?></button>
                            </form>
                            <!-- Formulaire pour supprimer la tâche -->
                            <form method="POST" style="display:inline;">
                                <input type="hidden" name="action" value="supprimer">
                                <input type="hidden" name="id" value="<?php echo htmlspecialchars($tache['id']); ?>">
                                <button type="submit" class="delete-btn" onclick="return confirm('Êtes-vous sûr de vouloir supprimer cette tâche ?')">Supprimer</button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</body>
</html>