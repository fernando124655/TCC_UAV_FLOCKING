"""Figura da validação dos módulos (Apêndice D do artigo).

Lê o validacao_<carimbo>.mat gravado por main_validacao_modulos.m e desenha:
  (a) Couzin: polarização p e momento angular m em função de Delta r_o,
      com Delta r_a = 14 m e 2 m (média das três sementes; barras: mínimo e máximo);
  (b) Olfati-Saber: distância ao vizinho mais próximo / d ao fim das execuções,
      com os parâmetros calibrados e com os do artigo original (5 sementes x 20 drones).

Uso (Python 3 com numpy, scipy e matplotlib):
    python figura_validacao_modulos.py dados/validacao_modulos/validacao_20261101_121846.mat fig_validacao_modulos.pdf

Escrito para o TCC de Fernando Souza Rodrigues (01/11/2026).
"""
import sys
import numpy as np
import scipy.io as sio
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

AZUL, LARANJA = '#2a78d6', '#eb6834'
TINTA, CINZA = '#222222', '#6b6b6b'


def carrega(arq):
    d = sio.loadmat(arq, squeeze_me=True, struct_as_record=False)
    return list(d['R'])


def painel_couzin(ax, R):
    for dra, cor in ((14, AZUL), (2, LARANJA)):
        rs = [r for r in R if r.alg == 'Couzin' and r.grupo == f'dra={dra}']
        dros = sorted({float(r.valores[1] - r.valores[0]) for r in rs})
        for nome, est, mk in (('p', '-', 'o'), ('m', '--', 's')):
            med, lo, hi = [], [], []
            for x in dros:
                v = [float(getattr(r, nome)) for r in rs if abs(float(r.valores[1] - r.valores[0]) - x) < 1e-9]
                med.append(np.mean(v)); lo.append(min(v)); hi.append(max(v))
            med, lo, hi = map(np.array, (med, lo, hi))
            ax.errorbar(dros, med, yerr=[med - lo, hi - med], color=cor, ls=est, lw=1.4, marker=mk, ms=4.5,
                        mfc='white' if nome == 'm' else cor, mew=1.2, capsize=2, elinewidth=0.8,
                        label=f'${nome}$, $\\Delta r_a = {dra}$ m')
    ax.set_xlabel('$\\Delta r_o$ (m)')
    ax.set_ylabel('$p$ e $m$')
    ax.set_ylim(-0.03, 1.05)
    ax.set_xlim(-0.5, 14.5)
    ax.set_title('(a) Couzin: largura da zona de orientação', fontsize=9.5, loc='left', color=TINTA)
    ax.legend(fontsize=7.5, frameon=False, loc='center right', handlelength=2.6)


def painel_olfati(ax, R):
    bins = np.arange(-0.125, 8.2, 0.25)
    for rot, cor, nome in (('calibrado', AZUL, 'calibrados'), ('artigo (d=7, r=1,2d, a=b=5)', LARANJA, 'do artigo')):
        rs = [r for r in R if r.alg == 'OlfatiSaber' and r.rotulo == rot]
        v = []
        for r in rs:
            P = np.asarray(r.pos_final, dtype=float)
            D = np.sqrt(((P[:, :, None] - P[:, None, :]) ** 2).sum(0))
            np.fill_diagonal(D, np.inf)
            v += list(D.min(1) / float(r.d_ref))
        v = np.clip(np.array(v), 0, 7.95)
        grupo = 100 * np.mean([float(r.frac_maior_grupo) for r in rs])
        ax.hist(v, bins=bins, weights=np.full(len(v), 1 / len(v)), color=cor, alpha=0.85 if cor == AZUL else 0.75,
                edgecolor='white', linewidth=0.6, label=f'{nome} (maior grupo: {grupo:.0f}%)')
    ax.axvline(1.0, color=CINZA, lw=0.8, ls=':')
    ax.set_xlabel('vizinho mais próximo / $d$')
    ax.set_ylabel('fração dos drones')
    ax.set_xlim(0, 8)
    ax.set_xticks([0, 1, 2, 4, 6, 8]); ax.set_xticklabels(['0', '1', '2', '4', '6', '$\\geq$8'])
    ax.set_title('(b) Olfati-Saber: espaçamento ao fim da execução', fontsize=9.5, loc='left', color=TINTA)
    ax.legend(fontsize=7.5, frameon=False, loc='upper right', title='parâmetros', title_fontsize=7.5)


def main(arq, saida):
    plt.rcParams.update({'font.family': 'STIXGeneral', 'mathtext.fontset': 'stix', 'font.size': 9,
                         'axes.edgecolor': CINZA, 'axes.labelcolor': TINTA, 'xtick.color': CINZA,
                         'ytick.color': CINZA, 'axes.linewidth': 0.7})
    R = carrega(arq)
    fig, (a, b) = plt.subplots(1, 2, figsize=(16 / 2.54, 6.2 / 2.54), gridspec_kw={'wspace': 0.32})
    painel_couzin(a, R)
    painel_olfati(b, R)
    for ax in (a, b):
        ax.grid(True, color='#e6e6e6', lw=0.5)
        ax.set_axisbelow(True)
        for s in ('top', 'right'):
            ax.spines[s].set_visible(False)
    fig.savefig(saida, bbox_inches='tight', pad_inches=0.02)
    if saida.endswith('.pdf'):
        fig.savefig(saida[:-4] + '.png', dpi=200, bbox_inches='tight', pad_inches=0.02)
    print('gravado', saida)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
