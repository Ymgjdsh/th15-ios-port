#pragma once
namespace th15 {
// Run through the ordinary Bomb service before hit feedback. A rejected
// eligibility check leaves the existing hit/deathbomb behavior untouched.
template<class Life, class Session, class Host>
int automatic_bomb(bool enabled, Life& life, Session& session, Host& host){
    if(!enabled||life.state!=1||life.invulnerability.current>0||session.bombs<=0||session.bomb_state!=0||!host.allow_bomb())return 0;
    const auto before=session.bombs;
    if(!host.begin_bomb())return -1;
    return session.bombs<before?1:-1;
}
}
