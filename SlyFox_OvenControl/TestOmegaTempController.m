%%
noz = OmegaTempController('yesromega2.colorado.edu',2000);
res = OmegaTempController('yesromega1.colorado.edu',2000);

%%
noz.readTemp()
res.readTemp()
%%
noz.setTemp(250)
noz.reset()
res.setTemp(100)
res.reset()