import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api.dart';

class VideoRoomScreen extends StatefulWidget {
  final Api api;
  final String title;
  final String tokenEndpoint;
  final bool publish;
  final String? callId;
  final String? ownedRoomId;
  const VideoRoomScreen({super.key,required this.api,required this.title,required this.tokenEndpoint,this.publish=true,this.callId,this.ownedRoomId});
  @override State<VideoRoomScreen> createState()=>_VideoRoomScreenState();
}
class _VideoRoomScreenState extends State<VideoRoomScreen> {
  final Room room=Room();
  bool loading=true, mic=true, camera=true, leaving=false;
  String? error;
  @override void initState(){super.initState();room.addListener(_changed);_connect();}
  void _changed(){if(mounted)setState((){});}
  Future<void> _connect() async {
    try {
      if(widget.publish){
        final permissions=await [Permission.camera,Permission.microphone].request();
        if(permissions.values.any((p)=>!p.isGranted))throw Exception('Camera and microphone permission required');
      }
      final data=await widget.api.post(widget.tokenEndpoint,{});
      await room.connect(data['url'] as String,data['token'] as String,roomOptions:const RoomOptions(adaptiveStream:true,dynacast:true));
      if(widget.publish){
        await room.localParticipant!.setMicrophoneEnabled(true);
        await room.localParticipant!.setCameraEnabled(true);
      }else{mic=false;camera=false;}
      if(mounted)setState(()=>loading=false);
    }catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  Future<void> _leave() async {
    if(leaving)return;
    setState(()=>leaving=true);
    try {
      await room.disconnect();
      if(widget.callId!=null)await widget.api.post('/calls/${widget.callId}/end',{});
      if(widget.ownedRoomId!=null)await widget.api.post('/rooms/${widget.ownedRoomId}/close',{});
    }catch(_){ /* local disconnect is still attempted */ }
    if(mounted)Navigator.pop(context);
  }
  @override void dispose(){room.removeListener(_changed);unawaited(room.dispose());super.dispose();}
  Future<void> _toggleMic()async{try{await room.localParticipant!.setMicrophoneEnabled(!mic);setState(()=>mic=!mic);}catch(e){_toast('$e');}}
  Future<void> _toggleCam()async{try{await room.localParticipant!.setCameraEnabled(!camera);setState(()=>camera=!camera);}catch(e){_toast('$e');}}
  void _toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  @override Widget build(BuildContext context){
    final members=<Participant>[
      if(widget.publish && !loading && error==null)room.localParticipant!,
      ...room.remoteParticipants.values
    ];
    return PopScope(canPop:false,onPopInvokedWithResult:(didPop,result){if(!didPop)_leave();},child:Scaffold(
      backgroundColor:const Color(0xff080d1b),
      appBar:AppBar(backgroundColor:Colors.transparent,title:Text(widget.title),actions:[Padding(padding:const EdgeInsets.only(right:12),child:Center(child:Text('${room.remoteParticipants.length+1} online')))]),
      body:Column(children:[Expanded(child:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Padding(padding:const EdgeInsets.all(22),child:Text(error!,textAlign:TextAlign.center))):members.isEmpty?const Center(child:Text('Waiting for participants...')):
        GridView.builder(padding:const EdgeInsets.all(12),gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:members.length==1?1:2,childAspectRatio:.68,crossAxisSpacing:10,mainAxisSpacing:10),itemCount:members.length,itemBuilder:(_,i)=>_VideoTile(participant:members[i]))),
        SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(18),child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
          if(widget.publish)...[
            _control(mic?Icons.mic:Icons.mic_off,mic?'Mute':'Unmute',_toggleMic),
            _control(camera?Icons.videocam:Icons.videocam_off,camera?'Camera off':'Camera on',_toggleCam)
          ],
          _control(Icons.call_end,'Leave',_leave,color:Colors.red.shade700),
        ])))
      ])));
  }
  Widget _control(IconData icon,String text,VoidCallback onTap,{Color? color})=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),decoration:BoxDecoration(color:color??const Color(0xff243054),borderRadius:BorderRadius.circular(18)),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:Colors.white),const SizedBox(height:5),Text(text,style:const TextStyle(fontSize:11))])));
}
class _VideoTile extends StatelessWidget {
  final Participant participant;
  const _VideoTile({required this.participant});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:participant,builder:(context,_){
    final pubs=participant.videoTrackPublications.where((p)=>!p.muted && p.track is VideoTrack).toList();
    return ClipRRect(borderRadius:BorderRadius.circular(20),child:Container(color:const Color(0xff1a2340),child:Stack(fit:StackFit.expand,children:[
      if(pubs.isNotEmpty)VideoTrackRenderer(pubs.first.track as VideoTrack) else const Center(child:Icon(Icons.person,size:82,color:Colors.white30)),
      Positioned(bottom:10,left:10,right:10,child:Text(participant.name.isNotEmpty?participant.name:participant.identity,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,shadows:[Shadow(blurRadius:8,color:Colors.black)])))
    ])));
  });
}
