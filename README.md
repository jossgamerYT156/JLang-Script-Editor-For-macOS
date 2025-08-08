# A very basic JLang IDE for MacOS written with an Spanish UI and basic OPCs.

## Supported Syntax(Example Script:
```
string A = "Some Text";

print @A;
@REM yes, we need to add the `@` to specify is a variable the thing we need to print.

function greeting[null] {
MAX_MEM = 512B @REM this part is still in development, i am trying to make so functions have a fixed memory heap, to make sure scripts don't crash all the time by using up all the App's memory.
  print "String literal, i guess?";
  
}

call greeting[];
@REM simple way to call functions actually, i could've made it worse.
@REM but i just couldn't make you guys suffer that much.
```
