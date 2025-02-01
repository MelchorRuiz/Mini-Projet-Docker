<?php
header("Content-Type: text/html");
?>

<body>

<h1>Un peu de littérature</h1>

<?php

$fortune = shell_exec("/usr/bin/fortune limerick");
$fortune = str_replace("\t\t--", "  --", $fortune);

echo $fortune;

?>

<h1>Une image du campus</h1>

<?php
$images = glob('/var/www/html/images/*');
$my_image = basename($images[rand(0, count($images) - 1)]);
echo "<img src=\"images/$my_image\"/>";
echo count($images)
?>

</body>