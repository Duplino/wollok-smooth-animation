# Wollok Animation Engine

## Unreal Engine? Quién te conoce.

Este motor de animaciones para Wollok Game permite mover objetos entre celdas con transiciones suaves en las 4 direcciones, en lugar del salto seco de celda a celda.

Funciona con sprites pre-generados: para cada objeto se necesita una imagen por cada frame de desplazamiento. Suena engorroso, pero el script `animationGenerator.py` las crea automáticamente a partir de un único PNG.

---

## 1. Generar los sprites

### Requisitos

- Python 3
- Pillow


### El PNG de entrada

- Tiene que tener el tamaño de una celda del juego (el mismo valor que `game.cellSize()`, por ejemplo 50×50 px).
- El sprite tiene que estar centrado y con fondo transparente.
- El nombre del archivo define el nombre de la carpeta de salida: `pepita.png` genera la carpeta `pepita/`.

### Uso

```bash
python animationGenerator.py pepita.png                 # 10 frames por lado
python animationGenerator.py pepita.png --frames 5      # 5 frames por lado
python animationGenerator.py pepita.png --paso 5        # 5 px por frame
python animationGenerator.py pepita.png --ejes h        # solo horizontal
python animationGenerator.py pepita.png --salida assets # crea assets/pepita/
```

| Opción | Descripción | Default |
|---|---|---|
| `--frames N` | Cantidad de frames por lado. | `10` |
| `--paso PX` | Píxeles que se mueve por frame. Alternativa a `--frames`: la cantidad de frames se calcula sola (tamaño ÷ paso, redondeado hacia arriba). | — |
| `--ejes` | Ejes a generar: `h`, `v` o ambos. | `h v` |
| `--salida` | Carpeta donde se crea la carpeta del sprite. | carpeta actual |

Lo más cómodo es correrlo con `--salida assets`, así los frames quedan directamente donde Wollok busca las imágenes.

### Qué genera

Con 10 frames por lado, `pepita.png` genera 41 imágenes:

```
assets/
  pepita/
    0.png                 sprite centrado
    h1.png ... h10.png    corrido hacia la derecha
    h-1.png ... h-10.png  corrido hacia la izquierda
    v1.png ... v10.png    corrido hacia arriba
    v-1.png ... v-10.png  corrido hacia abajo
```

El frame `n` es el sprite completamente fuera de la celda. Los signos siguen las coordenadas de Wollok: `x` crece hacia la derecha e `y` hacia arriba.

**Todos los sprites del juego tienen que generarse con la misma cantidad de frames**, porque el motor usa un único valor de `steps` para todos.

---

## 2. Usar el motor en Wollok

Copiá `animationEngine.wlk` en tu proyecto e importalo.

### Ejemplo completo

```wollok
import wollok.game.*
import animationEngine.animationEngine
import animationEngine.AnimatedSprite

object pepita inherits AnimatedSprite(name = "pepita", position = game.at(5, 8)) {}

program demo {
	game.title("Pepita")
	game.width(25)
	game.height(16)
	game.cellSize(50)

	// Configuración opcional del motor (antes de start)
	animationEngine.steps(10)       // igual al --frames del generador
	animationEngine.msPerFrame(50)  // 10 × 50 ms = 500 ms por movimiento

	game.addVisual(pepita)
	pepita.bindArrowKeys()

	animationEngine.start()
	game.start()
}
```

### Configuración: `animationEngine`

| Método | Descripción | Default |
|---|---|---|
| `steps(n)` | Frames por lado. **Tiene que coincidir con el `--frames` del generador**; si no, el motor pide imágenes que no existen y el juego falla al dibujar. | `10` |
| `msPerFrame(ms)` | Milisegundos entre frames. La duración de un movimiento es `steps × msPerFrame`. | `50` |
| `start()` | Arranca el motor. Se llama **una sola vez**, antes de `game.start()`, sin importar cuántos sprites haya. | — |

`steps` y `msPerFrame` se configuran **antes** de `start()`: el motor toma `msPerFrame` en ese momento para registrar su tick, así que cambiarlo después no tiene efecto.

### Crear un sprite: `mixin AnimatedSprite`

Cualquier objeto puede heredar el comportamiento:

```wollok
object pepita inherits AnimatedSprite(name = "pepita", position = game.at(5, 8)) {
	// métodos propios de pepita
	method volar() { ... }
}
```

| Parámetro | Descripción | Default |
|---|---|---|
| `name` | Nombre de la carpeta de frames dentro de `assets`. | obligatorio |
| `position` | Posición inicial. | `game.center()` |

No hace falta definir `image()`: el mixin ya se encarga de elegir el frame correcto.

### Métodos públicos del sprite

| Método | Descripción |
|---|---|
| `up()` / `down()` / `left()` / `right()` | Mueve el sprite una celda con animación. Se ignora si ya se está moviendo o si el destino queda fuera del tablero. |
| `bindArrowKeys()` | Atajo que asocia las flechas del teclado a los cuatro movimientos. |
| `isMoving()` | `true` mientras dura la animación de un movimiento. |
| `position()` | Posición del sprite. Cambia a la celda destino apenas empieza el movimiento, así las colisiones y la lógica del juego no esperan a que termine la animación. |
| `name()` | Nombre de la carpeta de frames. |

### Otras teclas

Si no querés usar las flechas, asociá las teclas a mano:

```wollok
keyboard.w().onPressDo({ pepita.up() })
keyboard.s().onPressDo({ pepita.down() })
keyboard.a().onPressDo({ pepita.left() })
keyboard.d().onPressDo({ pepita.right() })
```

### Mover desde el código

Los movimientos también se pueden disparar desde la lógica del juego, por ejemplo para un enemigo:

```wollok
game.onTick(1000, "patrulla", { enemigo.right() })
```

---


## AI Disclaimer

Este proyecto fue desarrollado con ayuda de Claude.