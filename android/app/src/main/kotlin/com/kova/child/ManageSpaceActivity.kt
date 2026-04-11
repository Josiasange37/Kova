package com.kova.child

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

/**
 * Cette activité remplace le bouton natif "Vider les données" (Clear Data)
 * par "Gérer l'espace" (Manage Space) dans les paramètres Android de l'application.
 * 
 * Lorsqu'ouverte, elle affiche une alerte et se ferme pour protéger la base de données.
 */
class ManageSpaceActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Bloque l'action système de suppression de données
        Toast.makeText(this, "🔐 Action verrouillée par KOVA Protection", Toast.LENGTH_LONG).show()
        
        // Ferme instantanément l'activité pour retourner aux paramètres
        finish()
    }
}
