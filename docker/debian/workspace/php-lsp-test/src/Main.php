<?php

declare(strict_types=1);

require_once __DIR__ . '/Greeter.php';

use App\Greeter;

$greeter = new Greeter();

echo $greeter->greet('Emacs') . PHP_EOL;
