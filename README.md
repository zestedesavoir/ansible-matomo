# Ansible matomo install

Ce playbook permet d'installer matomo sur un serveur en https.

## Prerequis 

- Systeme d'exploitation : debian 10
- Un nom de domaine (variable `matomo_domain`) valide pour letsencrypt (ce qui rend difficile cette installation sur une VM vagrant locale)

## Installation de matomo

L'installation de base se fait à partir de la commande suivante :

```
make install # installation des dépendances python (ansible et autres)
make build # installation des roles ansible
make deploy # installation de matomo (y compris l'installationd de mariadb, jusqu'au niveau de l'update de matomo)
```

### Zoom sur les playbooks

Lorsque l'on lance la commande  ̀make deploy` on demande l'executation des 3 playbooks suivants :

- `security.yml` : application de quelques règles de sécurités sur le serveurs (ufw)
- `matomo.yml`: installation et configuration de la version de matomo contenu dans le gestion de packet debian
- `update_matomo.yml`: mise à jour de matomo en version `matomo_version` (seule la version `4.2.1` a été testée avec succès)
- `post_install.yml`: migration de la base de donnée mariadb vers la nouvelle version de matomo

## Post install

Lorsque l'installation est réalisée via ce playbook, pour compléter l'installation il est necessaire d'aller dans `Administration > Diagnostic > Verification du système` et consulter les problèmes qui subsistent encore (probablement des trucs à changer coté serveur) et corriger ces problèmes.
Voici un éventail d'exemples de choses qui peuvent être marqués comme à corriger.
Ces actions sont bien sur automatisables, mais étant donné que ces remarques dépendent de la version de matomo installée, il faudrait gérer toute la matrice de compatibilité dans le playbook, ce qui peut le rendre un peut plus complexe.

### Conversion de table `utf8mb4`

Executez la commande suivante (et confirmez `yes` pour chaque demande) : `/usr/share/matomo/console core:convert-to-utf8mb4`

### Forcer l'utilisation ssl

Ouvrez le fichier ini de configuration `/usr/share/matomo/config/config.ini.php` et rajouter dans la section `General`, la ligne suivante :

```
force_ssl = 1
```

### Archivage automatique des rapports matomo

Ouvrez le fichier suivant : `/etc/cron.d/matomo-archive` et décommentez la seule ligne de parametrage l'intérieur.

Ensuite allez sur l'interface de matomo, `Administration > Système > Paramètres généraux` et cocher la case non pour `Archiver les rapports lorsqu'ils sont affichés depuis le navigateur`.

### Configuration de l'import de données depuis Google Analytics

[Lien de la documentation](https://matomo.org/docs/google-analytics-importer/#for-matomo-on-premise-and-matomo-for-wordpress)




