// import 'package:flutter/material.dart';
// // import 'package:flutter_svg/flutter_svg.dart';
// import 'home_page.dart'; // Import HomePage

// class SplashScreen extends StatelessWidget {
//   const SplashScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     Future.delayed(const Duration(seconds: 2), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => HomePage(onUpdate: (int , int , int , double , double , double ) {  },)),
//       );
//     });

//     return Scaffold(
//       body: Center(
//         child: Image.asset(
//           'assets/images/combiutility.png', // Ganti format ke PNG
//           semanticLabel: 'Splash Image',
//         ),
//         // child: SvgPicture.asset(
//         //   'assets/images/combiphar-seeklogo.svg',
//         //   semanticsLabel: 'Splash Image',
//         //   placeholderBuilder: (context) => const CircularProgressIndicator(),
//         // ),
//       ),
//     );
//   }
// }
