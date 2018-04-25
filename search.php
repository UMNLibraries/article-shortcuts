<?php
define('ES_ROOT', 'http://localhost:9200');

// Trim and cast to a string in case some sketchy array was passed in $_GET
$q = trim("{$_GET['q']}");
// Straight DOI match, query by _id
//if (preg_match('/^10\.\d{4}/', $q)) {
if (preg_match('~\b(10\.[\d]+(?:\.[\d]+)*\/(?:(?!["&\'])[[:graph:]])+)~', $q, $matches)) {
  $results = by_id(strtoupper(trim($matches[1], '.')));
}
else $results = by_query($q);

header("Content-type: application/json");
echo json_encode(array_map(function($a) {
  $record = [];
  foreach (['full_title','volume','issue','article','doi'] as $key) {
    $record[$key] = $a['_source'][$key];
  }
  return $record;
}, $results));

function by_id($id) {
  $curl = curl_init();
  curl_setopt($curl, CURLOPT_URL, ES_ROOT . '/article/article/' . strtoupper(urlencode($id)));
  curl_setopt($curl, CURLOPT_RETURNTRANSFER, TRUE);
  curl_setopt($curl, CURLOPT_HTTPGET, TRUE);
  $results = json_decode(curl_exec($curl), TRUE);
  return $results['found'] ? [$results] : [];
}

function by_query($query) {
  $qry = [
    'query' => [
      'bool' => [
        //'must' => [
        //  ['match' => ['article.title' => ['query' => "$query", 'operator' => 'or']]],
        //],
        'should' => [
          ['match' => [
            'article.title' => ['query' => "$query", 'operator' => 'and', 'boost' => 2]]
          ],
          [
            'nested' => [
              'path' => 'article.authors',
              'query' => [
                'match' => [
                  'article.authors.name.surname' => ['query' => "$query"]
                ]
              ]
            ]
          ]
        ]
      ]
    ]
  ];
  // echo(json_encode($qry, JSON_PRETTY_PRINT));

  $curl = curl_init();
  curl_setopt($curl, CURLOPT_URL, ES_ROOT . '/article/_search');
  curl_setopt($curl, CURLOPT_RETURNTRANSFER, TRUE);
  curl_setopt($curl, CURLOPT_HTTPHEADER, ['Content-type: application/json']);
  curl_setopt($curl, CURLOPT_HTTPGET, TRUE);
  curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($qry));
  $results = json_decode(curl_exec($curl), TRUE);
   print_r($results);
  return $results['hits']['hits'];
}
?>
