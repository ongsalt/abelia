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
- sampling rasterizationRoot
- pixel snapping


## Optimization 
- put some vertex data into uniform buffer
    - cuz its tree, compose say we can do gap buffer
    - compositorPrivate: skipping fields where `value == .identity`
    - 
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

# Styling
- modifier (like compose)
- builder method
    - `&mut self` -> quite awkward
    - wrap but with `func Self.margin() -> Margin<Self>`
- wrap it like flutter