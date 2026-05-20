class HomeState {
  const HomeState({this.token = ''});

  final String token;

  HomeState copyWith({String? token}) {
    return HomeState(token: token ?? this.token);
  }
}
