# SmallWorldInRam

This Cuberite plugin is aimed at servers that need maximum number of concurrent players where they all are
supposed to stay in a small limited area of the world, so the entire world is loaded into RAM and kept there
(no chunk loading and unloading during gameplay).

Also limits world generator, so that only chunks that are in the configured loaded zone are actually
generated, all the chunks outside the zone are left empty.

Only a single world is supported. That is, the same configuration is applied to each world.

The configuration is stored in SmallWorldInLua.conf next to the server executable. It specifies the coords
of the area which is loaded upon start. Chunks that intersect this area are kept in RAM all the time, chunks
completely out of this area are generated empty. The configuration file is a simple Lua file with the
following format:

```lua
MinX = -100
MaxX = 200
MinZ = -300
MaxZ = 400
```
