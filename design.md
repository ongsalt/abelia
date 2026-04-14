## Z index
- bigger children index = higher z index


## backing store
- normal layer wont have backing store
- composite layer have backing store(s)
    - 1 normally
    - 2 if it contains an effect layer even if we need to do 100 pass, we can just keep reusing these 2 textures alternately
- sizing? 


# TODO
- BRUSH
- effect shader
- fix affine position calculation
- stop doing descriptor indexing (descriptorBindingSampledImageUpdateAfterBind)
    - it say 91.73% of android device support this
    - supported
        - s25 -> snapdragon 8 elite?
    - not supported
        - Redmi Note 12 Pro (2023, ~300usd) -> Dimensity 1080
        - mi 14 -> snapdragon 8 gen 3 wtf
- sampling rasterizationRoot
- pixel snapping

## Optimization 
- put some vertex data into uniform buffer
- scrollNode
- build damage rect
- schedule phase 0 node simulteneously
<!-- - optmize root grouping -->


# Render loop
double buffering and vsync is enough

`DirtyFlags: dirty, mutated while rendering`

- EVERYTHING IS ON MAIN THREAD (except blocking method)
- mark dirty
- there must only be one instance of this
- while dirty || hasAnimationFrame 
    - (await) acquire frame
    - animation frame callback (this might mutate the tree but its fine)
    - if dirty (after updated)
        - flush tree state -> record render command
- back to idle