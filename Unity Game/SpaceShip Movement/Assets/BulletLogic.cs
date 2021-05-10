using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public class BulletLogic : MonoBehaviour
{
	
	private float dirx = 5;
	private float diry = 5;
	
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        transform.position = transform.position + new Vector3(dirx*Time.deltaTime, diry*Time.deltaTime, 0);
		Vector3 screenPoint = GameObject.Find("Main Camera").GetComponent<Camera>().WorldToViewportPoint(transform.position);
		bool onScreen = screenPoint.z > 0 && screenPoint.x > 0 && screenPoint.x < 1 && screenPoint.y > 0 && screenPoint.y < 1;
		if(!onScreen){
			Destroy(gameObject);
		}
    }
	
	//Sets the direction of bullet travel
	public void SetDir(float x, float y){
		float adjust = (float)Math.Sqrt(50f/(x*x+y*y));
		dirx = x*adjust;
		diry = y*adjust;
	}
}