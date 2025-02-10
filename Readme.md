# Mini Projet de synthèse
Melchor Ruiz González

Voici les urls
- http://o22408064-2:8080/dashboard/#/
- http://o22408064-2/web-simple/
- http://fortune.o22408064-2/
- http://utilisateurs.o22408064-2/
- http://clusterswarm.o22408064-2/
- http://flask.o22408064-2/

> Pour accéder aux applications, il est nécessaire d'entrer l'utilisateur « ```mel``` » et le mot de passe « ```hello``` »

Pour faciliter l'utilisation, un script a été créé pour la configuration des machines virtuelles qui automatise la création d'un cluster swarm, la création des volumes gluster et le déploiement de tous les services via une pile docker et un fichier docker-compose.yml.


Dans la partie « swarm-cluster », j'ai développé une simple application de tâches pour éviter de répéter la même page que dans la partie « reprise de contact », cette page continue d'utiliser php, mysql pour stocker les tâches et redis pour mettre en cache les tâches au lieu de les lire dans la base de données.


Dans la partie « fortune », j'ai réussi à réduire la taille de l'image originale de 602 Mo à seulement 65,5 Mo. 

Dans la partie authentification, un « middleware » a été créé et incorporé dans la section des points d'entrée du fichier traefik.yml afin que cet « middleware » puisse être appliqué à toutes les applications.
