# GAP Implementation
# $Id: patensor.gi,v 1.1 2010/09/17 11:29:22 oysteini Exp $

DeclareRepresentation(
        "IsQuiverProductDecompositionRep",
        IsComponentObjectRep,
        [ "factors", "lookup_table", "name_composer" ] );


InstallMethod( QuiverProduct,
        "for two quivers",
        ReturnTrue,
        [ IsQuiver, IsQuiver ],
        function( q1, q2 )

    local vertex_lists, vertex_names,
          arrow_lists, arrow_names, arrow_defs,
          lookup_table, make_name, make_arrow_def,
          i,
          product, decomposition;

    make_name := function( factors )
        return Concatenation( String( factors[ 1 ] ), "_", String( factors[ 2 ] ) );
    end;
    make_arrow_def := function( factors )
        return [ make_name( List( factors, SourceOfPath ) ),
                 make_name( List( factors, TargetOfPath ) ),
                 make_name( factors ) ];
    end;

    vertex_lists := Cartesian( VerticesOfQuiver( q1 ), VerticesOfQuiver( q2 ) );
    vertex_names := List( vertex_lists, make_name );

    arrow_lists := Concatenation( Cartesian( VerticesOfQuiver( q1 ), ArrowsOfQuiver( q2 ) ),
                                  Cartesian( ArrowsOfQuiver( q1 ), VerticesOfQuiver( q2 ) ) );
    arrow_names := List( arrow_lists, make_name );
    arrow_defs := List( arrow_lists, make_arrow_def );

    lookup_table := rec( );
    for i in [ 1 .. Length( vertex_lists ) ] do
        lookup_table.( vertex_names[ i ] ) := vertex_lists[ i ];
    od;
    for i in [ 1 .. Length( arrow_lists ) ] do
        lookup_table.( arrow_names[ i ] ) := arrow_lists[ i ];
    od;

    decomposition := Objectify( NewType( ListsFamily,
                                         IsQuiverProductDecomposition and IsQuiverProductDecompositionRep ),
                                rec( factors := [ q1, q2 ],
                                     lookup_table := lookup_table,
                                     name_composer := make_name ) );

    product := Quiver( vertex_names, arrow_defs );
    SetQuiverProductDecomposition( product, decomposition );

    return product;

end );


InstallMethod( WalkOfPathOrVertex,
        "for a path",
        [ IsPath ],
        WalkOfPath );
InstallMethod( WalkOfPathOrVertex,
        "for a vertex",
        [ IsVertex ],
        function( v ) return [ v ]; end );


InstallMethod( ReversePath,
        "for a path",
        [ IsPath ],
        function( path )
    return Product( Reversed( WalkOfPath( path ) ) );
end );


InstallMethod( IncludeInProductQuiver,
        "for list and quiver with product decomposition",
        ReturnTrue,
        [ IsDenseList, IsQuiver and HasQuiverProductDecomposition ],
        function( factors, q )

    local dec, make_name, walks, join, product_walk;

    dec := QuiverProductDecomposition( q );
    make_name := dec!.name_composer;
    
    walks := List( factors, WalkOfPathOrVertex );
    join := [ TargetOfPath( factors[ 1 ] ),
              SourceOfPath( factors[ 2 ] ) ];
    
    product_walk :=
      List( Concatenation( Cartesian( walks[ 1 ], [ join[ 2 ] ] ),
                           Cartesian( [ join[ 1 ] ], walks[ 2 ] ) ),
            function( pair ) return q.( make_name( pair ) ); end);

    return Product( product_walk );
end );


InstallMethod( ProjectFromProductQuiver,
        "for positive int and path",
        ReturnTrue,
        [ IsPosInt, IsPath ],
        function( index, path )

    local quiver, dec, project_arrow_or_vertex, walk;

    quiver := FamilyObj( path )!.quiver;
    dec := QuiverProductDecomposition( quiver );

    project_arrow_or_vertex := function( p )
        return dec!.lookup_table.( String( p ) )[ index ];
    end;

    walk := WalkOfPathOrVertex( path );
    return Product( List( walk, project_arrow_or_vertex ) );

end );


InstallMethod( \[\],
        "for quiver product decomposition",
        ReturnTrue,
        [ IsQuiverProductDecomposition, IsPosInt ],
        function( dec, index )
    return dec!.factors[ index ];
end );


InstallMethod( IncludeInPathAlgebra,
        "for path and path algebra",
        ReturnTrue,
        [ IsPath, IsAlgebra ],
        function( path, pa )
    local walk;

    walk := WalkOfPathOrVertex( path );
    return Product( List( walk, function( p ) return pa.( String( p ) ); end ) );
end );


InstallMethod( VerticesOfPathAlgebra,
        "for path algebra",
        [ IsAlgebra ],
        function( pa )
    return List( VerticesOfQuiver( QuiverOfPathAlgebra( pa ) ),
                 function( v ) return IncludeInPathAlgebra( v, pa ); end );
end );


InstallGlobalFunction( PathAlgebraElementTerms,
        function( elem )

    local terms, tip, tip_monom, tip_coeff, rest;

    terms := [ ];

    rest := elem;
    while true do # TODO should be while not IsZero( rest ), but that doesn't work
        tip := Tip( rest );
        tip_monom := TipMonomial( rest );
        tip_coeff := TipCoefficient( rest );
        if IsZero( tip_coeff ) then
            break;
        fi;
        rest := rest - tip;
        terms[ Length(terms) + 1 ] := rec( monom := tip_monom,
                                           coeff := tip_coeff );
    od;

    return terms;
end );


InstallMethod( SimpleTensor,
        "for list and path algebra",
        ReturnTrue,
        [ IsDenseList, IsAlgebra ],
        function( factors, pa )

    local parts, pairs, inc_paths, inc_terms;

    inc_paths :=
      function( paths )
        return IncludeInPathAlgebra( IncludeInProductQuiver( paths, QuiverOfPathAlgebra( pa ) ),
                                     pa );
    end;

    inc_terms :=
      function( terms )
        return terms[ 1 ].coeff * terms[ 2 ].coeff
               * inc_paths( [ terms[ 1 ].monom, terms[ 2 ].monom ] );
    end;

    parts := List( factors, PathAlgebraElementTerms );
    pairs := Cartesian( parts );
    return Sum( pairs, inc_terms );
end );


# Four methods for the TensorProductOfAlgebras to account for the possible
# combinations of argument types.  We would like to say that each argument
# should be ( IsPathAlgebra or IsSubalgebraFpPathAlgebra ), but it is not
# possible to combine filters using "or".

InstallMethod( TensorProductOfAlgebras,
        "for two path algebras",
        ReturnTrue,
        [ IsPathAlgebra, IsPathAlgebra ],
        function( pa1, pa2 )
    return TensorProductOfPathAlgebras( [ pa1, pa2 ] );
end );
InstallMethod( TensorProductOfAlgebras,
        "for two quotients of path algebras",
        ReturnTrue,
        [ IsSubalgebraFpPathAlgebra, IsSubalgebraFpPathAlgebra ],
        function( pa1, pa2 )
    return TensorProductOfPathAlgebras( [ pa1, pa2 ] );
end );
InstallMethod( TensorProductOfAlgebras,
        "for path algebra and quotient of path algebra",
        ReturnTrue,
        [ IsPathAlgebra, IsSubalgebraFpPathAlgebra ],
        function( pa1, pa2 )
    return TensorProductOfPathAlgebras( [ pa1, pa2 ] );
end );
InstallMethod( TensorProductOfAlgebras,
        "for quotient of path algebra and path algebra",
        ReturnTrue,
        [ IsSubalgebraFpPathAlgebra, IsPathAlgebra ],
        function( pa1, pa2 )
    return TensorProductOfPathAlgebras( [ pa1, pa2 ] );
end );


InstallGlobalFunction( TensorProductOfPathAlgebras,
        function( PAs )

    local field, Qs, product_q,
          orig_rels, induced_rels, comm_rels, tensor_rels,
          inc_q, inc_pa,
          get_relators, make_comm_rel,
          product_pa;

    field := LeftActingDomain( PAs[ 1 ] );
    if field <> LeftActingDomain( PAs[ 2 ] ) then
        Error( "path algebras must be over the same field" );
    fi;

    # Construct the product quiver and its path algebra:
    Qs := List( PAs, QuiverOfPathAlgebra );
    product_q := QuiverProduct( Qs[ 1 ], Qs[ 2 ] );
    product_pa := PathAlgebra( field, product_q );

    # Inclusion functions for product quiver and path algebra:
    inc_q := function( p )
        return IncludeInProductQuiver( p, product_q );
    end;
    inc_pa := function( p )
        return IncludeInPathAlgebra( p, product_pa );
    end;

    # Function for creating the commutativity relation of a
    # given pair [a,b] where a is an arrow in the first quiver
    # and b an arrow in the second:
    make_comm_rel :=
      function( arrows )
        local paths;
        paths := [ inc_q( [ arrows[ 1 ], SourceOfPath( arrows[ 2 ] ) ] ) *
                   inc_q( [ TargetOfPath( arrows[ 1 ] ), arrows[ 2 ] ] ),
                   inc_q( [ SourceOfPath( arrows[ 1 ] ), arrows[ 2 ] ] ) *
                   inc_q( [ arrows[ 1 ], TargetOfPath( arrows[ 2 ] ) ] ) ];
        return inc_pa( paths[ 1 ] ) - inc_pa( paths[ 2 ] );
    end;

    # Create all the commutativity relations:
    comm_rels := List( Cartesian( ArrowsOfQuiver( Qs[ 1 ] ),
                                  ArrowsOfQuiver( Qs[ 2 ] ) ),
                       make_comm_rel );

    # Function for finding the relations of a quotient of a path
    # algebra (or the empty list if the algebra is not a quotient):
    get_relators :=
      function( pa )
        if IsSubalgebraFpPathAlgebra( pa ) then
            return RelatorsOfFpAlgebra( pa );
        else
            return [ ];
        fi;
    end;

    # The relations of the two original path algebras:
    orig_rels := List( PAs, get_relators );

    # The original relations included into the product quiver:
    induced_rels := List( Concatenation( Cartesian( orig_rels[ 1 ], VerticesOfPathAlgebra( PAs[ 2 ] ) ),
                                         Cartesian( VerticesOfPathAlgebra( PAs[ 1 ] ), orig_rels[ 2 ] ) ),
                          function( factors ) return SimpleTensor( factors, product_pa ); end );

    # All the relations for the tensor product:
    tensor_rels := Concatenation( comm_rels, induced_rels );

    return product_pa / Ideal( product_pa, tensor_rels );

end );