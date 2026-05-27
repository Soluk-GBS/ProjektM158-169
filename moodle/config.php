<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

// -------------------------------------------------------
// Web-Adresse der neuen Instanz (FA-03: Port 80)
// -------------------------------------------------------
$CFG->wwwroot  = 'http://localhost';
$CFG->dataroot = '/var/moodledata';
$CFG->directorypermissions = 0777;

// -------------------------------------------------------
// Datenbank-Einstellungen (aus Umgebungsvariablen, FA-04)
// -------------------------------------------------------
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DB_HOST');
$CFG->dbname    = getenv('MOODLE_DB_NAME');
$CFG->dbuser    = getenv('MOODLE_DB_USER');
$CFG->dbpass    = getenv('MOODLE_DB_PASS');
$CFG->prefix    = 'mdl_';

require_once(__DIR__ . '/lib/setup.php');
