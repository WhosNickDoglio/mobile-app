package io.rebble.cobble.shared.di

import io.rebble.cobble.shared.domain.state.ConnectionState
import io.rebble.cobble.shared.domain.state.CurrentToken
import io.rebble.cobble.shared.domain.state.watchOrNull
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.*
import org.koin.core.qualifier.named
import org.koin.dsl.bind
import org.koin.dsl.module
import kotlin.coroutines.EmptyCoroutineContext

val stateModule = module {
    single(named("connectionState")) {
        MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    } bind StateFlow::class
    factory(named("connectedWatchMetadata")) {
        get<StateFlow<ConnectionState>>(named("connectionState"))
                .flatMapLatest { it.watchOrNull?.metadata?.take(1) ?: flowOf(null) }
                .filterNotNull()
    }
    single(named("connectionScope")) {
        MutableStateFlow<CoroutineScope>(CoroutineScope(EmptyCoroutineContext))
    } bind StateFlow::class

    single(named("currentToken")) {
        MutableStateFlow<CurrentToken>(CurrentToken.LoggedOut)
    } bind StateFlow::class
}