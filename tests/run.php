<?php
declare(strict_types=1);
$packageAutoload=dirname(__DIR__). '/vendor/autoload.php';if(is_file($packageAutoload))require $packageAutoload;
$roots=['Pam\\Native\\Video\\'=>dirname(__DIR__).'/src/','Pam\\Native\\'=>dirname(__DIR__,2).'/../pam-native/packages/native/src/'];spl_autoload_register(static function(string$c)use($roots):void{foreach($roots as$p=>$r)if(str_starts_with($c,$p)){$f=$r.str_replace('\\','/',substr($c,strlen($p))).'.php';if(is_file($f))require$f;return;}});
use Pam\Native\Element;use Pam\Native\Video\VideoPlayer;use Pam\Native\Video\VideoResizeMode;
$tests=[];$test=static function(string$n,Closure$f)use(&$tests):void{$tests[$n]=$f;};
$test('builds a renderable native player',static function():void{$player=VideoPlayer::make('https://cdn.example.test/master.m3u8')->autoPlay()->loop()->volume(.7)->resizeMode(VideoResizeMode::Cover)->progressEvery(250);if(!$player->toElement() instanceof Element)throw new RuntimeException('not renderable');});
$test('builder remains immutable',static function():void{$base=VideoPlayer::make('media/a.mp4');$changed=$base->autoPlay();if($base===$changed)throw new RuntimeException('builder mutated');});
$test('rejects insecure and invalid sources',static function():void{foreach(['http://example.test/a.mp4','']as$source){try{VideoPlayer::make($source);throw new RuntimeException('invalid source accepted');}catch(InvalidArgumentException){}}});
$failed=0;foreach($tests as$n=>$f){try{$f();fwrite(STDOUT,"PASS $n\n");}catch(Throwable$e){$failed++;fwrite(STDERR,"FAIL $n: {$e->getMessage()}\n");}}fwrite(STDOUT,count($tests)." tests, $failed failures\n");exit($failed?1:0);
