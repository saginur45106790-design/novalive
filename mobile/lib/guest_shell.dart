import 'package:flutter/material.dart';
import 'api.dart';
import 'room_screen.dart';
import 'network_status_screen.dart';

const _bg = Color(0xFF090F20);
const _panel = Color(0xFF18213B);
const _purple = Color(0xFF8655F7);
const _cyan = Color(0xFF17D6E6);
const _gold = Color(0xFFFFD079);

/// Public home: authentic data only. No invented hosts or fake live counts.
class GuestShell extends StatefulWidget {
  final Api api;
  final VoidCallback onSignIn;
  const GuestShell({super.key,required this.api,required this.onSignIn});
  @override State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> {
  int tab = 0;
  bool loading = false;
  String? warning;
  List<Map<String,dynamic>> hosts = [];
  List<Map<String,dynamic>> rooms = [];

  @override void initState(){super.initState();_refresh();}

  Future<void> _refresh() async {
    if(loading)return;
    setState((){loading=true;warning=null;});
    try {
      final data = await widget.api.publicGet('/public/discover');
      if(!mounted)return;
      setState((){
        hosts = (data['hosts'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
        rooms = (data['rooms'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      });
    } catch(e) {
      if(mounted)setState(()=>warning=e.toString());
    } finally {
      if(mounted)setState(()=>loading=false);
    }
  }

  void _loginRequired(String action) {
    showModalBottomSheet<void>(context:context,showDragHandle:true,
      backgroundColor:_panel,builder:(sheetContext)=>SafeArea(child:Padding(
      padding:const EdgeInsets.fromLTRB(24,12,24,25),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Icon(Icons.lock_person_outlined,size:43,color:_cyan),
        const SizedBox(height:14),
        Text('$action করতে অ্যাকাউন্ট প্রয়োজন',textAlign:TextAlign.center,
          style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
        const SizedBox(height:10),
        const Text('অ্যাকাউন্ট ছাড়াই Discover ও পাবলিক Live দেখা যাবে। কল, মেসেজ, গিফট এবং Wallet-এর জন্য লগইন করুন।',
          textAlign:TextAlign.center,style:TextStyle(color:Colors.white70)),
        const SizedBox(height:18),
        FilledButton.icon(onPressed:(){Navigator.pop(sheetContext);widget.onSignIn();},
          icon:const Icon(Icons.login),label:const Text('Sign in / Register')),
        TextButton(onPressed:()=>Navigator.pop(sheetContext),child:const Text('Continue as guest')),
      ]))));
  }

  Future<void> _watchRoom(Map<String,dynamic> room)async{
    // Display a consent confirmation. Real age verification requires a provider.
    final adult=await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(
      title:const Text('Public Live • 18+'),
      content:const Text('লাইভ দেখার জন্য আপনি অন্তত ১৮ বছর বয়সী এবং কমিউনিটি নিয়ম মেনে চলতে সম্মত—এটি নিশ্চিত করুন। Guest হিসেবে ক্যামেরা বা মাইক্রোফোন চালু হবে না।'),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('I am 18+ • Watch'))]));
    if(adult!=true||!mounted)return;
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>VideoRoomScreen(
      api:widget.api,title:'${room['title']}',
      tokenEndpoint:'/public/rooms/${room['id']}/watch',
      publish:false,guest:true)));
    await _refresh();
  }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor:_bg,
      appBar:AppBar(backgroundColor:_bg,title:Row(children:[
        const Icon(Icons.auto_awesome_rounded,color:_cyan,size:26),
        const SizedBox(width:8),
        const Text('NovaLive',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:-.5)),
        const SizedBox(width:8),
        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
          decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(12)),
          child:const Text('GUEST',style:TextStyle(color:_gold,fontSize:10,fontWeight:FontWeight.w800))),
      ]),actions:[
        IconButton(tooltip:'Server connection',icon:const Icon(Icons.wifi_tethering_rounded),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NetworkStatusScreen(api:widget.api)))),
        TextButton(onPressed:widget.onSignIn,child:const Text('Log in',style:TextStyle(color:_cyan))),
      ]),
      body:RefreshIndicator(onRefresh:_refresh,child:tab==0?_discover():tab==1?_live():_lockedPage()),
      bottomNavigationBar:NavigationBar(backgroundColor:_panel,selectedIndex:tab,
        onDestinationSelected:(v){setState(()=>tab=v);if(v<=1)_refresh();},
        destinations:const [
          NavigationDestination(icon:Icon(Icons.explore_outlined),selectedIcon:Icon(Icons.explore_rounded),label:'Explore'),
          NavigationDestination(icon:Icon(Icons.live_tv_outlined),selectedIcon:Icon(Icons.live_tv),label:'Live'),
          NavigationDestination(icon:Icon(Icons.chat_bubble_outline),label:'Chats'),
          NavigationDestination(icon:Icon(Icons.wallet_outlined),label:'Wallet'),
          NavigationDestination(icon:Icon(Icons.person_outline),label:'Me'),
        ]),
    );
  }

  Widget _discover()=>ListView(padding:const EdgeInsets.fromLTRB(16,14,16,24),children:[
    _hero(),const SizedBox(height:22),
    _heading('Explore your world','Choose a feature to get started'),
    const SizedBox(height:12),
    GridView.count(crossAxisCount:3,shrinkWrap:true,
      physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:10,crossAxisSpacing:10,
      childAspectRatio:1.25,children:[
        _quickAction(Icons.video_call_rounded,'Video call',()=>_loginRequired('ভিডিও কল')),
        _quickAction(Icons.live_tv_rounded,'Live',()=>setState(()=>tab=1)),
        _quickAction(Icons.groups_2_rounded,'Party',()=>_loginRequired('পার্টি রুম')),
        _quickAction(Icons.card_giftcard_rounded,'Gifts',()=>_loginRequired('গিফট পাঠানো')),
        _quickAction(Icons.chat_rounded,'Chat',()=>_loginRequired('চ্যাট')),
        _quickAction(Icons.verified_rounded,'Hosts',()=>_refresh()),
      ]),
    const SizedBox(height:22),
    _heading('Discover','Real hosts, meaningful conversations'),
    const SizedBox(height:12),
    Row(children:[_chip('Recommended',Icons.stars_rounded,true),const SizedBox(width:8),
      _chip('Verified',Icons.verified_outlined,false),const SizedBox(width:8),
      _chip('Party',Icons.groups_outlined,false)]),
    const SizedBox(height:20),
    _heading('Featured hosts','Visible only when approved by the platform'),
    const SizedBox(height:12),
    if(loading)_loading(),
    if(warning!=null)_error(),
    if(!loading && warning==null && hosts.isEmpty)_empty('No verified hosts yet','New hosts will appear after the admin approves them.'),
    for(final host in hosts)_hostCard(host),
    const SizedBox(height:18),
    _heading('Live now','Public streams you can watch as a guest'),
    const SizedBox(height:12),
    if(!loading && warning==null && rooms.isEmpty)_empty('No live streams right now','Refresh later to see public live streams.'),
    for(final room in rooms)_roomCard(room),
  ]);

  Widget _live()=>ListView(padding:const EdgeInsets.fromLTRB(16,16,16,26),children:[
    _heading('LIVE & PARTY','Be part of the moment'),const SizedBox(height:14),
    _featureTile(Icons.video_call_rounded,'Go Live','Approved hosts can broadcast to their audience.',()=>_loginRequired('লাইভ শুরু')),
    _featureTile(Icons.groups_2_rounded,'Party Rooms','Multi-person video rooms require sign-in.',()=>_loginRequired('পার্টি রুমে যোগ দেওয়া')),
    const SizedBox(height:24),
    _heading('Public Live','Watch without creating an account'),const SizedBox(height:10),
    if(loading)_loading(),if(warning!=null)_error(),
    if(!loading && warning==null && rooms.isEmpty)_empty('Nothing is live yet','No fake online hosts are shown.'),
    for(final room in rooms)_roomCard(room),
  ]);

  Widget _lockedPage(){
    final names=['Explore','Live','Chats','Wallet','My account'];
    final icons=[Icons.explore_rounded,Icons.live_tv_rounded,Icons.chat_bubble_rounded,Icons.account_balance_wallet_rounded,Icons.person_rounded];
    return ListView(padding:const EdgeInsets.symmetric(horizontal:20,vertical:28),children:[
      Container(padding:const EdgeInsets.all(26),decoration:BoxDecoration(
        gradient:const LinearGradient(colors:[Color(0xFF433579),Color(0xFF162C52)]),borderRadius:BorderRadius.circular(26)),
        child:Column(children:[Icon(icons[tab],size:58,color:_cyan),const SizedBox(height:16),
          Text(names[tab],style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:10),
          const Text('Browse freely without registration. To keep calls, messages and payments safe, sign in when you want to use this feature.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70)),
          const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:widget.onSignIn,icon:const Icon(Icons.login),label:const Text('Sign in / Create account'))),
          TextButton(onPressed:()=>setState(()=>tab=0),child:const Text('Back to Explore',style:TextStyle(color:_cyan))),
        ])),
    ]);
  }

  Widget _hero()=>Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(
    gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[Color(0xFF7D3FDF),Color(0xFF363E99),Color(0xFF08607E)]),
    borderRadius:BorderRadius.circular(28)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
        decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(50)),
        child:const Text('GLOBAL VIDEO COMMUNITY  •  18+',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,letterSpacing:.8))),
      const SizedBox(height:14),const Text('Discover your\nnext connection.',
        style:TextStyle(fontSize:29,fontWeight:FontWeight.w900,height:1.12)),
      const SizedBox(height:10),const Text('লাইভ দেখুন, নতুন মানুষ খুঁজুন—প্রথমে অ্যাকাউন্ট লাগবে না।',style:TextStyle(color:Colors.white70)),
      const SizedBox(height:18),Wrap(spacing:10,runSpacing:10,children:[
        FilledButton.icon(onPressed:()=>setState(()=>tab=1),style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:_bg),
          icon:const Icon(Icons.play_arrow_rounded),label:const Text('Explore Live')),
        OutlinedButton.icon(onPressed:()=>_loginRequired('ভিডিও কল'),
          icon:const Icon(Icons.video_call_rounded),label:const Text('Video Call'),
          style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Colors.white54))),
      ])]));

  Widget _quickAction(IconData icon,String title,VoidCallback tap)=>Material(
    color:_panel,borderRadius:BorderRadius.circular(16),child:InkWell(
      borderRadius:BorderRadius.circular(16),onTap:tap,
      child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        Icon(icon,color:_cyan,size:28),const SizedBox(height:7),
        Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
      ])));

  Widget _heading(String title,String caption)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
    const SizedBox(height:3),Text(caption,style:const TextStyle(fontSize:12,color:Colors.white60)),
  ]);
  Widget _chip(String label,IconData icon,bool active)=>InkWell(borderRadius:BorderRadius.circular(20),
    onTap:()=>active?_refresh():_loginRequired(label),
    child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),decoration:BoxDecoration(
      color:active?_purple:_panel,borderRadius:BorderRadius.circular(20)),
      child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:14),const SizedBox(width:5),Text(label,style:const TextStyle(fontSize:11))])));
  Widget _loading()=>const Padding(padding:EdgeInsets.all(22),child:Center(child:CircularProgressIndicator(color:_cyan)));
  Widget _error()=>Card(color:_panel,child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
    const Icon(Icons.wifi_off_rounded,size:32,color:_gold),const SizedBox(height:8),
    const Text('Unable to load live data',style:TextStyle(fontWeight:FontWeight.bold)),
    Text(warning!,maxLines:3,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70,fontSize:12)),
    const SizedBox(height:10),Wrap(spacing:8,children:[TextButton(onPressed:_refresh,child:const Text('Retry')),
      TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NetworkStatusScreen(api:widget.api))),child:const Text('Test server'))]),
  ])));
  Widget _empty(String title,String detail)=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(
    color:_panel,borderRadius:BorderRadius.circular(18)),child:Column(children:[
      const Icon(Icons.people_outline_rounded,color:_cyan,size:34),const SizedBox(height:6),
      Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),
      Text(detail,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:Colors.white60)),
    ]));
  Widget _hostCard(Map<String,dynamic> host){
    final name='${host['name']??'Host'}';
    return Card(margin:const EdgeInsets.only(bottom:12),color:_panel,child:Padding(
      padding:const EdgeInsets.all(14),child:Row(children:[
        _avatar(name),const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),
          const Text('★ Approved Host',style:TextStyle(color:_gold,fontSize:11)),
          if('${host['bio']??''}'.trim().isNotEmpty)Text('${host['bio']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:Colors.white54)),
        ])),
        IconButton(tooltip:'Video call',onPressed:()=>_loginRequired('ভিডিও কল'),icon:const Icon(Icons.video_call_rounded,color:_cyan)),
        IconButton(tooltip:'Chat',onPressed:()=>_loginRequired('চ্যাট'),icon:const Icon(Icons.chat_bubble_outline,color:_purple)),
      ])));
  }
  Widget _avatar(String name)=>Container(width:53,height:53,decoration:const BoxDecoration(
    shape:BoxShape.circle,gradient:LinearGradient(colors:[_purple,_cyan])),
    child:Center(child:Text(name.isEmpty?'?':name.substring(0,1).toUpperCase(),style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))));
  Widget _roomCard(Map<String,dynamic> room)=>Card(color:_panel,margin:const EdgeInsets.only(bottom:12),
    child:ListTile(contentPadding:const EdgeInsets.all(15),
      leading:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(
        color:_purple.withValues(alpha:.2),borderRadius:BorderRadius.circular(14)),
        child:const Icon(Icons.live_tv_rounded,color:_cyan)),
      title:Text('${room['title']??'Live'}',maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontWeight:FontWeight.w700)),
      subtitle:Text('Public LIVE  •  ${room['owner_name']??'Host'}',style:const TextStyle(color:Colors.white60,fontSize:12)),
      trailing:const Icon(Icons.play_circle_fill_rounded,color:_gold),onTap:()=>_watchRoom(room)));
  Widget _featureTile(IconData icon,String title,String caption,VoidCallback onTap)=>Card(color:_panel,
    child:ListTile(contentPadding:const EdgeInsets.all(15),leading:Icon(icon,color:_cyan,size:31),
      title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text(caption),trailing:const Icon(Icons.arrow_forward_ios_rounded,size:17),onTap:onTap));
}
