#!/usr/bin/env python3
"""make_fig_example_degenerate -- the manuscript's Figure fig:example-degenerate (the Example of the introduction), TikZ
code written to <out>/fig_example_degenerate.tex (plain Python, standard library only; ~20 s).

  python3 benchmarks/figures/make_fig_example_degenerate.py [--out=<dir>]     (default: benchmarks/out/paper/figures)

The instance: c1(x) = x1^2 - x2^2 - 4 = 0, c2(x) = x1 - 4 = 0, no objective; the feasible set is the two points
(4, +-sqrt(12)), where the constraint Jacobian has full rank. Three panels, one per (weight, kernel) choice:
(a) gamma = (1, 1), p = 2; (b) gamma = (1, 4), p = 2; (c) gamma = (1, 1), p = 6. Each panel draws, on the frame
[-3, 5] x [-3.8, 3.8] (TikZ unit 0.6 cm), the level sets of the selected merit Theta(x) = sum_i gamma_i |c_i(x)|^p / p
(marching squares on a 241 x 161 grid), the zero sets of c1 and c2, the feasible points, the stationary points of Theta
(located by a damped 2-D Newton search from a 31 x 21 grid of starts and classified by the Hessian: a filled dot for a
spurious local minimizer, an open dot for a saddle), the boundary of the spurious minimizer's basin (dashed; the
steepest-descent flow from a 121 x 80 grid, classified by its end point), and the steepest-descent paths of Theta from
the starts (-2.6, 2.6) and (0.8, 2.6). The caption is the manuscript's (captions are Yifan's). The defaults are the
arguments that wrote the manuscript's file (Overleaf commit 9254149):
  --a=0 --b=4 --frame=-3,5,-3.8,3.8 --scale=0.6 --starts=-2.6:2.6,0.8:2.6
(c2(x) = x1 + a x2 - b; the tilt a stays 0 for the manuscript). They can still be overridden on the command line;
emit.sh passes only --out. The stationary points of each panel are printed on stdout.
"""
import os, sys
_opt = {"a": "0", "b": "4", "frame": "-3,5,-3.8,3.8", "scale": "0.6", "starts": "-2.6:2.6,0.8:2.6"}
_opt.update(dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a))
OUTDIR = _opt.get("out", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "out", "paper", "figures"))
import math
from collections import defaultdict
def contours(F,xs,ys,level):
    NX,NY=len(xs),len(ys); segs=[]
    table={1:[(3,0)],2:[(0,1)],3:[(3,1)],4:[(1,2)],5:[(3,0),(1,2)],6:[(0,2)],7:[(3,2)],8:[(2,3)],9:[(0,2)],10:[(0,1),(2,3)],11:[(1,2)],12:[(1,3)],13:[(0,1)],14:[(3,0)]}
    for i in range(NX-1):
        for j in range(NY-1):
            a,b,c,d=F[i][j],F[i+1][j],F[i+1][j+1],F[i][j+1]
            idx=(a>level)|((b>level)<<1)|((c>level)<<2)|((d>level)<<3)
            if idx in (0,15): continue
            def lerp(p,q,fp,fq):
                t=(level-fp)/(fq-fp) if fq!=fp else 0.5
                return (p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1]))
            P=[(xs[i],ys[j]),(xs[i+1],ys[j]),(xs[i+1],ys[j+1]),(xs[i],ys[j+1])]
            e=[lerp(P[0],P[1],a,b),lerp(P[1],P[2],b,c),lerp(P[2],P[3],c,d),lerp(P[3],P[0],d,a)]
            for (u,v) in table[idx]: segs.append((e[u],e[v]))
    key=lambda p:(round(p[0],5),round(p[1],5)); adj=defaultdict(list)
    for n,(p,q) in enumerate(segs): adj[key(p)].append(n); adj[key(q)].append(n)
    used=[False]*len(segs); lines=[]
    for n in range(len(segs)):
        if used[n]: continue
        used[n]=True; p,q=segs[n]; line=[p,q]
        for end in (1,0):
            cur=line[-1] if end else line[0]
            while True:
                nxt=[m for m in adj[key(cur)] if not used[m]]
                if not nxt: break
                m=nxt[0]; used[m]=True; a,b=segs[m]; new=b if key(a)==key(cur) else a
                if end: line.append(new)
                else: line.insert(0,new)
                cur=new
        lines.append(line)
    return lines
def grad(f,x,y,h=1e-6): return ((f(x+h,y)-f(x-h,y))/(2*h),(f(x,y+h)-f(x,y-h))/(2*h))
def flow(f,x,y,targets,step=0.01,maxit=6000):
    for _ in range(maxit):
        gx,gy=grad(f,x,y); n=math.hypot(gx,gy)
        if n<1e-9: break
        x-=step*gx/n; y-=step*gy/n
        for k,(tx,ty) in targets.items():
            if math.hypot(x-tx,y-ty)<0.03: return k,(x,y)
    best=min(targets,key=lambda k:math.hypot(x-targets[k][0],y-targets[k][1])); return best,(x,y)
def path(f,x,y,targets,step=0.01,maxit=6000):
    pts=[(x,y)]
    for _ in range(maxit):
        gx,gy=grad(f,x,y); n=math.hypot(gx,gy)
        if n<1e-9: break
        x-=step*gx/n; y-=step*gy/n; pts.append((x,y))
        if any(math.hypot(x-tx,y-ty)<0.03 for tx,ty in targets.values()): break
    return pts
def panel(f,X0,X1,Y0,Y1,levels,zero_sets,stationary,targets,starts,scale,title,NX=241,NY=161,separatrix=True):
    xs=[X0+(X1-X0)*i/(NX-1) for i in range(NX)]; ys=[Y0+(Y1-Y0)*j/(NY-1) for j in range(NY)]
    F=[[f(x,y) for y in ys] for x in xs]
    out=['\\begin{tikzpicture}[x=%gcm,y=%gcm]'%(scale,scale),'\\begin{scope}','\\clip (%g,%g) rectangle (%g,%g);'%(X0,Y0,X1,Y1),'\\fill[black!12] (%g,%g) rectangle (%g,%g);'%(X0,Y0,X1,Y1)]
    for lv in levels:
        for line in contours(F,xs,ys,lv):
            if len(line)<3: continue
            out.append('\\draw[white, line width=0.45pt] '+' -- '.join('(%.3f,%.3f)'%p for p in line[::2]+[line[-1]])+';')
    # basin separatrix: classify a coarse grid by the flow endpoint
    if separatrix and any(k.startswith('trap') for k in targets):
        BX,BY=121,80; bxs=[X0+(X1-X0)*i/(BX-1) for i in range(BX)]; bys=[Y0+(Y1-Y0)*j/(BY-1) for j in range(BY)]
        trapkey='trap'
        B=[[1.0 if flow(f,x,y,targets)[0].startswith('trap') else 0.0 for y in bys] for x in bxs]
        for line in contours(B,bxs,bys,0.5):
            if len(line)<3: continue
            out.append('\\draw[black, densely dashed, line width=0.5pt] '+' -- '.join('(%.3f,%.3f)'%p for p in line)+';')
    for style,pts in zero_sets:
        out.append('\\draw[%s] '%style+' -- '.join('(%.3f,%.3f)'%p for p in pts)+';')
    for (x,y) in starts:
        pts=path(f,x,y,targets); out.append('\\draw[black!70, line width=1.1pt, -{Stealth[length=4.5pt]}] '+' -- '.join('(%.3f,%.3f)'%p for p in pts[::25]+[pts[-1]])+';')
        out.append('\\fill[black!70] (%.3f,%.3f) circle (1.4pt);'%(x,y))
    out.append('\\end{scope}')
    out.append('\\draw[black, line width=0.4pt] (%g,%g) rectangle (%g,%g);'%(X0,Y0,X1,Y1))
    for kind,(x,y) in stationary:
        if kind=='feasible': out.append('\\node[star, star points=5, star point ratio=2.2, fill=black, inner sep=1.4pt] at (%.3f,%.3f) {};'%(x,y))
        elif kind=='trap': out.append('\\fill[black] (%.3f,%.3f) circle (1.8pt);'%(x,y))
        else: out.append('\\draw[black, fill=white, line width=0.6pt] (%.3f,%.3f) circle (1.6pt);'%(x,y))
    out.append('\\node[anchor=north, font=\\scriptsize, align=center] at (%g,%g) {%s};'%((X0+X1)/2,Y0-0.08,title))
    out.append('\\end{tikzpicture}'); return out


# ---------- regular, asymmetric variant: c1 = x1^2 - x2^2 - 4, c2 = x1 + A x2 - B ----------
A=float(_opt.get("a","0.15")); B=float(_opt.get("b","2.5"))
def c1(x1,x2): return x1*x1-x2*x2-4
def c2(x1,x2): return x1+A*x2-B
def sp(t,q): return math.copysign(abs(t)**q,t)
def theta(g1,g2,p): return lambda x1,x2: g1*abs(c1(x1,x2))**p/p+g2*abs(c2(x1,x2))**p/p
def gradH(g1,g2,p,x1,x2):
    C1,C2=c1(x1,x2),c2(x1,x2); n1=(2*x1,-2*x2); n2=(1.0,A)
    w1,w2=g1*sp(C1,p-1),g2*sp(C2,p-1); k1,k2=g1*(p-1)*abs(C1)**(p-2),g2*(p-1)*abs(C2)**(p-2)
    g=(w1*n1[0]+w2*n2[0], w1*n1[1]+w2*n2[1])
    H=[[k1*n1[0]*n1[0]+k2*n2[0]*n2[0]+w1*2, k1*n1[0]*n1[1]+k2*n2[0]*n2[1]],[k1*n1[0]*n1[1]+k2*n2[0]*n2[1], k1*n1[1]*n1[1]+k2*n2[1]*n2[1]+w1*(-2)]]
    return g,H
def stationary_points(g1,g2,p,X0,X1,Y0,Y1):
    found=[]
    for i in range(31):
        for j in range(21):
            x,y=X0+(X1-X0)*i/30,Y0+(Y1-Y0)*j/20
            ok=False
            for it in range(200):
                g,H=gradH(g1,g2,p,x,y); det=H[0][0]*H[1][1]-H[0][1]*H[1][0]
                if abs(det)<1e-14: break
                dx=( H[1][1]*g[0]-H[0][1]*g[1])/det; dy=(-H[1][0]*g[0]+H[0][0]*g[1])/det
                s=1.0; st=math.hypot(dx,dy)
                if st>0.5: s=0.5/st
                x-=s*dx; y-=s*dy
                if math.hypot(*gradH(g1,g2,p,x,y)[0])<1e-11: ok=True; break
            if not ok or not (X0<=x<=X1 and Y0<=y<=Y1): continue
            if abs(c1(x,y))<1e-6 and abs(c2(x,y))<1e-6: continue
            if any(math.hypot(x-u,y-v)<1e-3 for u,v,_ in found): continue
            g,H=gradH(g1,g2,p,x,y); tr=H[0][0]+H[1][1]; det=H[0][0]*H[1][1]-H[0][1]*H[1][0]
            kind='MIN' if (det>0 and tr>0) else ('MAX' if (det>0 and tr<0) else 'saddle')
            found.append((x,y,kind))
    return found
X0,X1,Y0,Y1=[float(v) for v in _opt.get("frame","-3,3,-2,2").split(",")]; SCALE=float(_opt.get("scale","0.78"))
qa,qb,qc=A*A-1,-2*A*B,B*B-4; disc=math.sqrt(qb*qb-4*qa*qc)
feas=[(B-A*y,y) for y in ((-qb+disc)/(2*qa),(-qb-disc)/(2*qa))]
for (fx,fy) in feas:
    det=(2*fx)*A-(-2*fy)*1.0
    print('feasible point (%.3f, %.3f): det J = %.3f'%(fx,fy,det))
hyp=lambda s:[(s*math.sqrt(4+t*t),t) for t in [Y0+(Y1-Y0)*k/80 for k in range(81)]]
zs=[('blue!70!black, line width=0.9pt',hyp(1)),('blue!70!black, line width=0.9pt',hyp(-1)),('red!70!black, line width=0.9pt',[(B-A*Y0,Y0),(B-A*Y1,Y1)])]
def levels(f,tref,n=8):
    vals=[f(x,y) for x in (X0,X1) for y in (Y0,Y1)]; tmax=max(vals)
    base=max(tref*0.2,1e-3); return [base*(tmax/base)**((k+0.5)/n) for k in range(n)]
pan=[((1,1),2,'(a) $\\gamma=(1,1)$, $\\varphi(t)=\\frac{1}{2}t^2$ \\\\ \\textbf{Classical ALM}'),((1,4),2,'(b) $\\gamma=(1,4)$, $\\varphi(t)=\\frac{1}{2}t^2$ \\\\ \\textbf{Ours}, custom weights'),((1,1),6,'(c) $\\gamma=(1,1)$, $\\varphi(t)=\\frac{1}{2}t^2 + \\frac{1}{6} t^6$ \\\\ \\textbf{Ours}, custom kernel')]
out=['%% GENERATED: regular instance x1^2-x2^2-4=0, x1-%g=0 (no objective); level sets of the selected merit, stationary points, basin separatrix, steepest-descent paths.'%B,'\\begin{figure}[t]\\centering']
for (g1,g2),p,title in pan:
    f=theta(g1,g2,p); pts=stationary_points(g1,g2,p,X0,X1,Y0,Y1)
    print(title, [(round(x,3),round(y,3),k,round(f(x,y),3)) for x,y,k in pts])
    targets={'feasible':feas[0],'feasible2':feas[1]}; stat=[('feasible',feas[0]),('feasible',feas[1])]
    nt=0; tref=None
    for x,y,k in pts:
        if k=='MIN': nt+=1; targets['trap%d'%nt]=(x,y); stat.append(('trap',(x,y))); tref=f(x,y)
        elif k=='saddle': stat.append(('saddle',(x,y)))
    if tref is None: tref=f(-1.7,0)
    starts=[tuple(float(v) for v in s.split(":")) for s in _opt.get("starts","-2.6:1.6,0.6:1.6").split(",")]
    out+=panel(f,X0,X1,Y0,Y1,levels(f,tref),zs,stat,targets,starts,SCALE,title)
out.append(r"""\caption{Contour plots of the infeasibility merit for the constraints $c_1(x) = x_1^2 - x_2^2 - 4 = 0$ (blue) and $c_2(x) = x_1 - 4 = 0$ (red). The feasible set is the two points $(4, \pm\sqrt{12})$ (stars), where the line crosses the hyperbola and the constraint Jacobian has full rank. White curves are level sets of the infeasibility merit $\Theta(x) = \sum_i \gamma_i |c_i(x)|^p/p$ (see Theorem~\ref{thm:merit} for a rigorous definition); a filled dot is a spurious local minimizer of $\Theta$, at which the two constraint gradients are parallel, and open dots represent saddles of $\Theta$. The dashed curve traces the boundary of the spurious minimizer's basin of attraction, and the two thin paths are steepest-descent paths of $\Theta$ from two starting points. (a) With unit weights and the quadratic kernel à la vanilla ALM, a path started left of the dashed curve ends infeasible; (b) weight $4$ for the second constraint and (c) a polynomial kernel both remove the spurious minimizer, hence every path ends at a feasible point.}""")
out.append('\\label{fig:example-degenerate}\\end{figure}')
os.makedirs(OUTDIR, exist_ok=True)
open(os.path.join(OUTDIR, 'fig_example_degenerate.tex'),'w',encoding='utf-8').write('\n'.join(out)+'\n')
print('wrote', os.path.join(OUTDIR, 'fig_example_degenerate.tex'))
