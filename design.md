## Z index
- bigger children index = higher z index


## backing store
- normal layer wont have backing store
- composite layer have backing store(s)
    - 1 normally
    - 2 if it contains an effect layer even if we need to do 100 pass, we can just keep reusing these 2 textures alternately
- sizing? 