# Cry of Fear: Source

Projeto de fã para levar a campanha cooperativa original de Cry of Fear ao Garry’s Mod (Source 1). O trabalho começa em `cof_campaign_01` e preserva o playermodel escolhido no GMod. Não é um gamemode novo nem um projeto oficial.

Este repositório contém **o código Lua do coop e seus testes**, não um addon jogável. O código cobre a introdução individual (ver ou pular), as interações e transições de mapa, o inventário entre trechos, a ambientação e as regras do lago para o Watro e o dano na água.

## Estado

- **Coop:** prioridade do projeto. A última compilação de teste do lago é a v10, com validação offline registrada e reteste no GMod pendente.
- **Single-player M3:** trilha separada, não incluída nesta publicação.

## Dependências

Os testes usam simulações das interfaces do motor. Para jogar, são necessários o Garry’s Mod, os mapas compilados e seus recursos, além do Cry of Fear Weapon Pack, do Cry of Fear SNPCs e da VJ Base. Esses arquivos e addons não são distribuídos aqui. Clonar o repositório, sozinho, não instala a campanha.

## Testes

A partir da raiz, execute cada cenário com Lua 5.1 ou LuaJIT:

```sh
for test in tests/coop_*.lua; do
  lua "$test" || exit 1
done
```

Esses cenários não iniciam o GMod nem validam renderização, áudio ou desempenho em jogo.

## Créditos

Cry of Fear e seus recursos são da Team Psykskallar e dos criadores creditados. Garry’s Mod, Source e os addons externos pertencem a seus respectivos autores. Este repositório não concede direitos sobre material de terceiros.
