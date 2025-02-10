# Mini Projet de synthèse
Melchor Ruiz González

Pour accéder aux pages, la commande suivante doit être exécutée
```bash
ssh -J o22408064@acces-tp.iut45.univ-orleans.fr -o StrictHostKeyChecking=no -L 8080:0.0.0.0:80 -L 8081:0.0.0.0:8080 -N o22408064@o22408064-2
```
password = ```dr4E8u```

Et voici les urls
- http://localhost:8081/dashboard/#/
- http://localhost:8080/web-simple/
- http://fortune.localhost:8080/
- http://utilisateurs.localhost:8080/
- http://clusterswarm.localhost:8080/
- http://flask.localhost:8080/

> Pour accéder aux applications, il est nécessaire d'entrer l'utilisateur « ```mel``` » et le mot de passe « ```hello``` »

Pour faciliter l'utilisation, un script a été créé pour la configuration des machines virtuelles qui automatise la création d'un cluster swarm, la création des volumes gluster et le déploiement de tous les services via une pile docker et un fichier docker-compose.yml.


Dans la partie « swarm-cluster », j'ai développé une simple application de tâches pour éviter de répéter la même page que dans la partie « reprise de contact », cette page continue d'utiliser php, mysql pour stocker les tâches et redis pour mettre en cache les tâches au lieu de les lire dans la base de données.


Dans la partie « fortune », j'ai réussi à réduire la taille de l'image originale de 602 Mo à seulement 65,5 Mo. 

Dans la partie authentification, un « middleware » a été créé et incorporé dans la section des points d'entrée du fichier traefik.yml afin que cet « middleware » puisse être appliqué à toutes les applications.
