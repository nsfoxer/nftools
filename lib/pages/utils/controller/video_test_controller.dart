
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoTestController extends GetxController {

  Player player = Player();
  VideoController? controller;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    controller = VideoController(player);
    player.open(
      Media("https://upos-sz-mirror08c.bilivideo.com/upgcxcode/78/33/500001624443378/500001624443378-1-192.mp4?e=ig8euxZM2rNcNbRVhwdVhwdlhWdVhwdVhoNvNC8BqJIzNbfq9rVEuxTEnE8L5F6VnEsSTx0vkX8fqJeYTj_lta53NCM=&uipk=5&nbs=1&deadline=1747227662&gen=playurlv2&os=08cbv&oi=236137231&trid=357e9a1526374f8a9a0e4d7fd1fd8df8T&mid=3546730691823690&platform=html5&og=hw&upsig=f3a9bc5720bdca9472dfff944a7d7fb9&uparams=e,uipk,nbs,deadline,gen,os,oi,trid,mid,platform,og&bvc=vod&nettype=0&bw=65530&orderid=0,1&buvid=&build=0&mobi_app=&f=T_0_0&logo=80000000")
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}