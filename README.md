## General information
This docker container uses the latest autopostgresqlbackup package from the [k0lter/autopostgresqlbackup](https://github.com/k0lter/autopostgresqlbackup) repo.
The image is based on debian trixie and has Postgresql 17.6 client and mariadb 11.8 client installed.\
most of the configuration can be edited using docker enviroment variables (PG_*)

## Installation

    docker pull jeroenkeizernl/autopostgresqlbackup

## Configuration
backups will be made to the /backup folder, so you can mount your real backup target to that folder.

### Environment variables
Variables are prefixed with PG_ and mapped directly with the configuration options of the original project. Some of the options are disabled due tot the nature of running it inside an docker container.
At a minimum the settings PG_DBENGINE, PG_USERNAME, PG_PASSWORD (or PG_PASSWORD_SECRET) and PG_DBHOST need to be configured, the rest is optional

| Docker variable    | Autopostgresqlbackup variable | Default                            | Configurable | Description                                                                            |
| ------------------ | ----------------------------- | ---------------------------------- | ------------ | -------------------------------------------------------------------------------------- |
| TZ                 | none                          | Host timezone                      | ✅            | Can be used to change the timezone of the image, this important for the cron deamon    |
| CRON_SCHEDULE      | none                          | 0 2 * * *                          | ✅            | a cron schedule to use for the autobackup in the default cron format (m h dom mon dow) |
|                    | MAILADDR                      | NULL                               | ❌            | the docker image has no mail support so this is set to disabled                        |
| PG_DBENGINE        | DBENGINE                      | postgresql                         | ✅            | Database engines supported: postgresql, mysql                                          |
|                    | SU_USERNAME                   | NULL                               | ❌            | The docker container has only one user, this settings is not exposed for that reason   |
| PG_USERNAME        | USERNAME                      | NULL                               | ✅            | Username to access the Database server                                                 |
| PG_PASSWORD        | PASSWORD                      | NULL                               | ✅            | Password to access then Database server                                                |
| PG_PASSWORD_SECRET | PASSWORD                      |                                    | ✅            | Name of a docker secret to use instead of the plaintext password option above          |
| PG_DBHOST          | DBHOST                        | NULL                               | ✅            | Host name (or IP address) of the Database server.                                      |
| PG_DBPORT          | DBPORT                        | 3306 for MySQL 5432 for PostgreSQL | ✅            | Port of Database server.                                                               |
| PG_DBNAMES         | DBNAMES                       | all                                | ✅            | List of database(s) names(s) to backup.                                                |
| PG_DBEXCLUDE       | DBEXCLUDE                     | none                               | ✅            | List of databases to exclude                                                           |
| PG_GLOBALS_OBJECTS | GLOBALS_OBJECTS               | postgres_globals                   | ✅            | Virtual database name used to dump global objects (users, roles, tablespaces)          |
|                    | BACKUPDIR                     | /backup                            | ❌            | Backup target directory                                                                |
| PG_CREATE_DATABASE | CREATE_DATABASE               | yes                                | ✅            | Include CREATE DATABASE statement                                                      |
| PG_DOWEEKLY        | DOWEEKLY                      | 7                                  | ✅            | Which day do you want weekly backups?                                                  |
| PG_DOMONTHLY       | DOMONTHLY                     | 1                                  | ✅            | Which day do you want monthly backups?                                                 |
| PG_BRDAILY         | BRDAILY                       | 14                                 | ✅            | Backup retention count for daily backups.                                              |
| PG_BRWEEKLY        | BRWEEKLY                      | 5                                  | ✅            | Backup retention count for weekly backups.                                             |
| PG_BRMONTHLY       | BRMONTHLY                     | 12                                 | ✅            | Backup retention count for monthly backups.                                            |
| PG_COMP            | COMP                          | gzip                               | ✅            | Compression tool.                                                                      |
| PG_COMP_OPTS       | COMP_OPTS                     | NULL                               | ✅            | Compression tools options.                                                             |
|                    | PGDUMP                        |                                    | ❌            | pg_dump path                                                                           |
|                    | PGDUMPALL                     |                                    | ❌            | pg_dumpall path                                                                        |
|                    | PGDUMP_OPTS                   |                                    | ❌            | Options string for use with all_dump                                                   |
|                    | PGDUMPALL_OPTS                |                                    | ❌            | Options string for use with pg_dumpall                                                 |
|                    | MY                            |                                    | ❌            | mysql path                                                                             |
|                    | MYDUMP                        |                                    | ❌            | mysqldump                                                                              |
|                    | MYDUMP_OPTS                   |                                    | ❌            | Options string for use with mysqldump                                                  |
| PG_EXT             | EXT                           | sql                                | ✅            | Backup files extension                                                                 |
| PG_PERM            | PERM                          | 600                                | ✅            | Backup files permission                                                                |
| PG_MIN_DUMP_SIZE   | MIN_DUMP_SIZE                 | 256                                | ✅            | Minimum size (in bytes) for a dump/file (compressed or not).                           |
|                    | ENCRYPTION                    |                                    | ✅            | Enable encryption (asymmetric) with GnuPG.                                             |
|                    | ENCRYPTION_PUBLIC_KEY         |                                    | ❌            | Encryption public key (path to the key)                                                |
|                    | ENCRYPTION_SUFFIX             |                                    | ❌            | Suffix for encrypted files                                                             |
|                    | PREBACKUP                     |                                    | ❌            | Command or script to execute before backups                                            |
|                    | POSTBACKUP                    |                                    | ❌            | Command or script to execute after backups                                             |
|                    | DEBUG                         | yes                                | ❌            | Debug mode                                                                             |
|                    | GPG_HOMEDIR                   |                                    | ❌            | Encryption prerequisites                                                               |



## Running the container
### Docker commandline
    docker run -d --name autopostgresqlbackup \
      -e PG_DBENGINE=postgresql
      -e PG_DBHOST=myserver \
      -e PG_USERNAME=postgres \
      -e PG_PASSWORD=mypassword \
      -e TZ="Europe/Amsterdam" \
      -v /etc/localtime:/etc/localtime:ro \
      -v /my/backup/dir:/backup
      jeroenkeizernl/autopostgresqlbackup:latest

### Docker commandline; Test database connection only
    docker run -d --name autopostgresqlbackup \
      -e PG_DBENGINE=postgresql
      -e PG_DBHOST=myserver \
      -e PG_USERNAME=postgres \
      -e PG_PASSWORD=mypassword \
      -e TZ="Europe/Amsterdam" \
      -v /etc/localtime:/etc/localtime:ro \
      -v /my/backup/dir:/backup
      jeroenkeizernl/autopostgresqlbackup:latest test-connection

### Docker commandline; run onetime backup
    docker run -d --name autopostgresqlbackup \
      -e PG_DBENGINE=postgresql
      -e PG_DBHOST=myserver \
      -e PG_USERNAME=postgres \
      -e PG_PASSWORD=mypassword \
      -e TZ="Europe/Amsterdam" \
      -v /etc/localtime:/etc/localtime:ro \
      -v /my/backup/dir:/backup
      jeroenkeizernl/autopostgresqlbackup:latest backup-now

### With docker-compose and password

    version: '3.5'

    services:
      autopostgresqlbackup:
        image: jeroenkeizernl/autopostgresqlbackup:latest
        container_name: autopostgresqlbackup
        environment:
          - PG_DBENGINE = postgresql
          - PG_DBHOST = myserver
          - PG_USERNAME = postgres
          - PG_PASSWORD = mypassword
          - TZ = "Europe/Amsterdam"
        volumes:
        - /my/backups/dir:/backup
        - /etc/localtime:/etc/localtime:ro

### With docker-compose and password-file

    version: '3.5'

    services:
      autopostgresqlbackup:
        image: jeroenkeizernl/autopostgresqlbackup:latest
        container_name: autopostgresqlbackup
        environment:
          - PG_DBENGINE = postgresql
          - PG_DBHOST = myserver
          - PG_USERNAME = postgres
          - PG_PASSWORD_SECRET = posgre-pass
          - TZ = "Europe/Amsterdam"
        volumes:
        - /my/backups/dir:/backup
        - /etc/localtime:/etc/localtime:ro
        secrets:
        - posgre-pass

    secrets:
      posgre-pass:
        file: /path/to/file/that/contains/password

## Git repo
https://github.com/JeroenKeizerNL/autopostgresqlbackup
