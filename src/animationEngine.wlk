/*
 * animationEngine.wlk
 * https://github.com/Duplino/wollok-smooth-animation
 *
 * Librería de movimiento suave de una celda a otra en Wollok Game.
 *
 * Wollok dibuja cada visual dentro de una celda y lo mueve de a saltos
 * enteros. Para simular un desplazamiento suave se usan DOS visuales
 * durante el movimiento:
 *
 *   - El sprite, que ya está en la celda destino y va "entrando" a ella.
 *   - Una estela (Trail), que queda en la celda origen y va "saliendo".
 *
 * Como ambas imágenes se desplazan la misma cantidad de píxeles en cada
 * frame, juntas se ven como un único sprite deslizándose entre las dos
 * celdas. Al terminar, la estela se elimina y el sprite queda centrado.
 *
 * Los frames los genera el script de Python a partir de un PNG centrado:
 *
 *   pepita/0.png            -> sprite centrado, sin desplazamiento
 *   pepita/h1 ... h10.png   -> corrido hacia la derecha (h10 = afuera)
 *   pepita/h-1 ... h-10.png -> corrido hacia la izquierda
 *   pepita/v1 ... v10.png   -> corrido hacia arriba
 *   pepita/v-1 ... v-10.png -> corrido hacia abajo

 */

import wollok.game.*


/*
 * Configuración global de la animación y punto de arranque del motor.
 */
object animationEngine {
	// Milisegundos entre un frame y el siguiente.
	// Duración de un movimiento completo = steps × msPerFrame (10 × 50 = 500 ms).
	var property msPerFrame = 50

	// Cantidad de frames por lado (el "n" de h1 ... hn).
	// Debe coincidir con --frames del generador; si no, se piden imágenes
	// que no existen y el juego falla al dibujar.
	var property steps = 10

	// Registra un único tick global que hace avanzar a todos los sprites
	// en movimiento. Llamar una sola vez desde el programa, antes de
	// game.start(), sin importar cuántos sprites haya.
	method start() {
		game.onTick(msPerFrame, "animation", { clock.tick() })
	}
}


/*
 * Interfaz común de las direcciones.
 *
 * Cada dirección solo define su eje y su signo (métodos abstractos)
 */
mixin Direction {
	// Eje del movimiento: "h" (horizontal) o "v" (vertical).
	// Es también el prefijo de los archivos de frames.
	method axis()

	// Sentido sobre el eje: 1 (derecha / arriba) o -1 (izquierda / abajo).
	// Sigue las coordenadas de Wollok: x crece a la derecha, y hacia arriba.
	method sign()

	// Posición vecina en esta dirección. Usa right/up con el signo,
	// ya que pos.right(-1) equivale a pos.left(1) y pos.up(-1) a pos.down(1).
	method next(pos) =
		if (self.axis() == "h") pos.right(self.sign()) else pos.up(self.sign())
}

object rightDirection inherits Direction {
	override method axis() = "h"
	override method sign() = 1
}

object leftDirection inherits Direction {
	override method axis() = "h"
	override method sign() = -1
}

object upDirection inherits Direction {
	override method axis() = "v"
	override method sign() = 1
}

object downDirection inherits Direction {
	override method axis() = "v"
	override method sign() = -1
}


/*
 * Lista de sprites que están en medio de un movimiento.
 *
 * En cada tick del motor le pide a cada uno que avance un frame.
 * Los sprites quietos no están en la lista, así que no consumen nada.
 */
object clock {
	const animated = []

	// Empieza a animar un sprite (lo llama AnimatedSprite.move).
	method animate(obj) { animated.add(obj) }

	// Deja de animarlo (lo llama AnimatedSprite.advance al llegar al último frame).
	method finish(obj) { animated.remove(obj) }

	// Se recorre una copia porque advance() puede llamar a finish() y
	// sacar elementos de la lista original mientras se la recorre.
	method tick() { animated.copy().forEach({ o => o.advance() }) }
}


/*
 * Visual temporal que queda en la celda de origen durante un movimiento
 * y muestra la parte del sprite que todavía no terminó de salir.
 * No tiene lógica propia: el AnimatedSprite le cambia la imagen en cada frame.
 */
class Trail {
	var property position
	var property image
}


/*
 * Comportamiento de movimiento animado, para heredar en cualquier objeto.
 */
mixin AnimatedSprite {
	// Nombre de la carpeta de frames dentro de assets, ej. "pepita".
	const property name

	// Posición lógica del sprite. Cambia a la celda destino apenas empieza
	// el movimiento, así colisiones y demás lógica del juego la ven de
	// inmediato; la animación es solo visual.
	var property position = game.center()

	// Estado del movimiento en curso:
	//   direction -> hacia dónde se mueve (o se movió por última vez)
	//   step      -> frame actual, de 0 a animationEngine.steps()
	//   trail     -> estela en la celda origen; null si está quieto
	var direction = rightDirection
	var step = 0
	var trail = null


	// --- Interfaz pública ---

	// Intentan mover el sprite una celda. Se ignoran si ya se está moviendo
	// o si el destino queda fuera del tablero.
	method up()    { self.move(upDirection) }
	method down()  { self.move(downDirection) }
	method right() { self.move(rightDirection) }
	method left()  { self.move(leftDirection) }

	// Atajo para controlar el sprite con las flechas del teclado. Pues addVisualCharacter no es compatible
	method bindArrowKeys() {
		keyboard.up().onPressDo({ self.up() })
		keyboard.down().onPressDo({ self.down() })
		keyboard.right().onPressDo({ self.right() })
		keyboard.left().onPressDo({ self.left() })
	}

	// Hay movimiento en curso mientras exista la estela.
	method isMoving() = trail != null


	// --- Animación / Interfaz privada ---

	// Ruta del frame n en la dirección actual. El signo de la dirección
	// convierte n en el desplazamiento real del archivo:
	//   frame(3) con rightDirection -> "pepita/h3.png"
	//   frame(3) con leftDirection  -> "pepita/h-3.png"
	//   frame(0) en cualquier dirección -> "pepita/0.png"
	//     (el centro no tiene eje, por eso se trata aparte)
	method frame(n) {
		const offset = direction.sign() * n
		const fileName = if (offset == 0) "0" else direction.axis() + offset.toString()
		return name + "/" + fileName + ".png"
	}

	// Imagen que Wollok dibuja en la celda del sprite (la de destino).
	// Durante el movimiento, step - steps va de -10 a -1: el sprite arranca
	// completamente del lado del origen y se acerca al centro frame a frame.
	// Por ejemplo, moviéndose a la derecha, en step 0 muestra h-10 (todo
	// afuera, a la izquierda) y en step 9 muestra h-1 (casi centrado).
	method image() =
		if (self.isMoving()) self.frame(step - animationEngine.steps()) else name + "/0.png"

	method isInsideBoard(pos) =
		pos.x().between(0, game.width() - 1) and pos.y().between(0, game.height() - 1)

	// Inicia un movimiento de una celda:
	//   1. Crea la estela en la celda actual, mostrando el sprite centrado.
	//   2. Mueve la posición lógica al destino (ahí image() lo dibuja afuera,
	//      del lado del origen, así que visualmente todavía no se movió).
	//   3. Se anota en el clock para avanzar un frame por tick.
	method move(dir) {
		const destination = dir.next(position)
		if (not self.isMoving() and self.isInsideBoard(destination)) {
			direction = dir
			step = 0
			trail = new Trail(position = position, image = self.frame(0))
			game.addVisual(trail)
			position = destination
			clock.animate(self)
		}
	}

	// Un frame de animación, llamado por el clock en cada tick.
	// La estela se corre hacia el destino (frame(step): h1, h2, ...)
	// mientras el sprite entra desde el origen (ver image()).
	// En el último paso la estela ya salió por completo y el sprite quedó
	// centrado, así que se elimina la estela y termina el movimiento.
	method advance() {
		step += 1
		if (step == animationEngine.steps()) {
			game.removeVisual(trail)
			trail = null
			clock.finish(self)
		} else {
			trail.image(self.frame(step))
		}
	}
}
