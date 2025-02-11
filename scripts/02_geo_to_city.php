<?php

$basePath = dirname(__DIR__);
foreach(glob($basePath . '/cunli/geo/*.json') AS $geoFile) {
    $p = pathinfo($geoFile);
    $cityPath = $p['dirname'] . '/city/' . $p['filename'];
    if(!file_exists($cityPath)) {
        mkdir($cityPath, 0777, true);
    }
    $topoPath = str_replace('geo', 'topo', $cityPath);
    if(!file_exists($topoPath)) {
      mkdir($topoPath, 0777, true);
  }
  $geo = json_decode(file_get_contents($geoFile), true);
  $fc = [];
  foreach($geo['features'] AS $f) {
    if(isset($f['properties']['COUNTY'])) {
        $key = $f['properties']['COUNTY'];
    } elseif(isset($f['properties']['C_Name'])) {
        $key = $f['properties']['C_Name'];
    } elseif(isset($f['properties']['COUNTYNAME'])) {
        $key = $f['properties']['COUNTYNAME'];
        
    } else {
        print_r($f['properties']); exit();
    }
    if(!isset($fc[$key])) {
      $fc[$key] = [];
    }
    $fc[$key][] = $f;
  }
  foreach($fc AS $key => $features) {
    $cityFile = "{$cityPath}/{$key}.json";
    if(!file_exists($cityFile)) {
      file_put_contents($cityFile, json_encode([
        'type' => 'FeatureCollection',
        'features' => $features
      ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    }
    $topoFile = "{$topoPath}/{$key}.json";
    if(!file_exists($topoFile)) {
      exec("/usr/local/bin/mapshaper -i {$cityFile} -o format=topojson {$topoFile}");
    }
  }
}